import SwiftUI
import WebKit
import Foundation
import UIKit

class HapticManager {
    static let shared = HapticManager()
    
    private init() {}
    
    func impact(style: UIImpactFeedbackGenerator.FeedbackStyle) {
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.prepare()
        generator.impactOccurred()
    }
    
    func notification(type: UINotificationFeedbackGenerator.FeedbackType) {
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(type)
    }
}

class WebViewModel: NSObject, ObservableObject {
    @Published var urlString: String = "https://yossidisk.github.io/Shamze/shamzeAppHome.html"

    @Published var isLoading: Bool = false
    @Published var hasSiteData: Bool = false
    @Published var currentTitleValue: String = ""
    
    @Published var comparisonResults: [ComparisonProduct] = []
    @Published var showComparisonResults: Bool = false
    
    @Published var hasComparisonResults: Bool = false
    @Published var hasUnreadResults: Bool = false

    func performPriceComparison(query: String) {
        guard let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://kufu51g8uk.execute-api.il-central-1.amazonaws.com/stag/search?query=\(encodedQuery)&items=10") else {
            return
        }
        
        print("Debug - Starting price comparison search for: \(query)")
        
        URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("Error fetching comparison data: \(error)")
                    self?.hasComparisonResults = false
                    return
                }
                
                guard let data = data else {
                    print("Debug - No data received from comparison API")
                    self?.hasComparisonResults = false
                    return
                }
                
                do {
                    let products = try JSONDecoder().decode([ComparisonProduct].self, from: data)
                    print("Debug - Received \(products.count) results for query: \(query)")
                    self?.comparisonResults = products
                    let hasResults = !products.isEmpty
                    self?.hasComparisonResults = hasResults
                    if hasResults {
                        self?.hasUnreadResults = true
                        // הוספת משוב רטט כשיש תוצאות
                        HapticManager.shared.impact(style: .medium)
                    }
                } catch {
                    print("Error decoding comparison data: \(error)")
                    self?.hasComparisonResults = false
                }
            }
        }.resume()
    }

    private(set) var webView: WKWebView
    private let keywordsToCheck = ["הנחה", "לקוחות", "עסקה", "משלוחים", "Shop", "מוצר"]
    
    private var storedDataCache: [String: APIResponse] = [:]
    private let cacheTimeLimit: TimeInterval = Configuration.cacheTimeLimit

    
    func checkForTitleValue() {
        guard let domain = getDomainFromURL(webView.url?.absoluteString ?? "") else {
            print("Debug - No valid domain for title check")
            return
        }
        
        guard let siteData = storedDataCache[domain] else {
            print("Debug - No cached data for title check")
            return
        }
        
        if siteData.titleParam.isEmpty {
            print("Debug - Empty titleParam in site data")
            return
        }
        
        print("Debug - Searching for title with selector:", siteData.titleParam)
        
        let script = """
            function findTitle() {
                try {
                    const elements = document.querySelectorAll(`\(siteData.titleParam)`);
                    let titles = [];
                    elements.forEach(element => {
                        if (element && element.textContent) {
                            titles.push(element.textContent.trim());
                        }
                    });
                    return titles;
                } catch (error) {
                    console.error('Error in findTitle:', error);
                    return [];
                }
            }
            findTitle();
        """
        
        webView.evaluateJavaScript(script) { [weak self] result, error in
            if let error = error {
                print("Debug - Error finding title elements:", error)
                return
            }
            
            if let titles = result as? [String], let firstTitle = titles.first {
                DispatchQueue.main.async {
                    self?.currentTitleValue = firstTitle
                    print("Debug - Set title value to:", firstTitle)
                    self?.performPriceComparison(query: firstTitle)  // מבצע חיפוש אוטומטי
                    self?.hasUnreadResults = true  // מסמן שיש תוצאות חדשות
                }
            }
        }
    }
            
    override init() {
        let configuration = WKWebViewConfiguration()
        let contentController = WKUserContentController()
        
        // Security settings
        configuration.allowsInlineMediaPlayback = false
        configuration.mediaTypesRequiringUserActionForPlayback = .all
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true
        
        // Configure to open links within the app
        let preferences = WKWebpagePreferences()
        preferences.allowsContentJavaScript = true
        configuration.defaultWebpagePreferences = preferences
        
        // הסרנו את ה-script שהתערב בהתנהגות הלינקים
        configuration.userContentController = contentController
        
        self.webView = WKWebView(frame: .zero, configuration: configuration)
        
        super.init()
        
        // Basic configuration for internal link handling
        webView.configuration.preferences.isTextInteractionEnabled = true
        
        webView.addObserver(self, forKeyPath: #keyPath(WKWebView.url), options: .new, context: nil)
        loadStoredCache()
        
        // Add message handlers
        contentController.add(self, name: "keywordFound")
        contentController.add(self, name: "keywordNotFound")
        contentController.add(self, name: "openUrl")
        contentController.add(self, name: "showMessage")
        
        // Load initial URL
        if let url = URL(string: "https://yossidisk.github.io/Shamze/shamzeAppHome.html") {
            webView.load(URLRequest(url: url))
        }
    }
    
    override func observeValue(forKeyPath keyPath: String?,
                             of object: Any?,
                             change: [NSKeyValueChangeKey : Any]?,
                             context: UnsafeMutableRawPointer?) {
        if keyPath == "URL" {
            hasSiteData = false
            checkCurrentPage()
            
            // אם יש לנו מידע מהAPI עבור הדומיין הנוכחי, נחפש את האלמנט
            if let domain = getDomainFromURL(webView.url?.absoluteString ?? ""),
               let siteData = storedDataCache[domain] {
                checkForTitleValue()
            }
        }
    }

    private func loadStoredCache() {
        if let data = UserDefaults.standard.data(forKey: "siteDataCache"),
           let cache = try? JSONDecoder().decode([String: APIResponse].self, from: data) {
            // ניקוי מידע ישן
            let currentTime = Date().timeIntervalSince1970
            storedDataCache = cache.filter { $0.value.timestamp > currentTime - cacheTimeLimit }
            saveCache()
        }
    }

    private func saveCache() {
        if let encoded = try? JSONEncoder().encode(storedDataCache) {
            UserDefaults.standard.set(encoded, forKey: "siteDataCache")
        }
    }

    private func checkCurrentPage() {
        guard let currentURL = webView.url,
              let domain = getDomainFromURL(currentURL.absoluteString) else {
            print("Debug - No valid domain found for URL:", webView.url?.absoluteString ?? "nil")
            hasSiteData = false
            return
        }
        
        print("\nDebug - Checking domain:", domain)
        
        // בדיקת מידע בזיכרון המקומי
        if let cachedData = storedDataCache[domain] {
            let currentTime = Date().timeIntervalSince1970
            if currentTime - cachedData.timestamp < cacheTimeLimit {
                print("Debug - Found cached data for domain:", domain)
                
                if cachedData.siteName == "NOT_FOUND" {
                    print("Debug - Cached data shows: Site not found")
                    hasSiteData = false
                    return
                }
                
                print("Debug - Cached data:", cachedData)
                self.hasSiteData = true
                return
            } else {
                print("Debug - Cache expired for domain:", domain)
                storedDataCache.removeValue(forKey: domain)
                saveCache()
            }
        } else {
            print("Debug - No cache found for domain:", domain)
        }
        
        // הוספנו - אם אין מידע ב-cache, נבדוק מול השרת
        fetchSiteData(domain: domain)
        
        // הרצת הבדיקה של מילות המפתח במקביל
        let script = """
            function checkPageContent() {
                const keywords = ["הנחה", "לקוחות", "עסקה", "משלוחים", "Shop", "מוצר"];
                const siteHTML = document.documentElement.outerHTML;
                console.log("Checking for keywords:", keywords.join(", "));
                for (const keyword of keywords) {
                    if (siteHTML.includes(keyword)) {
                        console.log("Found keyword:", keyword);
                        webkit.messageHandlers.keywordFound.postMessage(keyword);
                        return;
                    }
                }
                webkit.messageHandlers.keywordNotFound.postMessage("");
            }
            checkPageContent();
        """
        
        webView.evaluateJavaScript(script) { [weak self] result, error in
            if let error = error {
                print("Debug - Error checking page content:", error)
            }
        }
    }
    
    private func sanitizeURL(_ urlString: String) -> String {
        // וידוא שה-URL מתחיל בפרוטוקול מאובטח
        if !urlString.hasPrefix("http://") && !urlString.hasPrefix("https://") {
            return "https://" + urlString
        }
        return urlString
    }

    func loadUrl() {
        let sanitizedURL = sanitizeURL(urlString)
        guard let url = URL(string: sanitizedURL) else { return }
        let request = URLRequest(url: url)
        webView.load(request)
        hasSiteData = false
    }
    
    private func getDomainFromURL(_ urlString: String) -> String? {
        guard let url = URL(string: urlString),
              let host = url.host else { return nil }
        return host
    }
    
    private func fetchSiteData(domain: String) {
        guard let url = URL(string: Configuration.siteEndpoint(domain: domain)) else {
            #if DEBUG
            print("Debug - Invalid URL for domain: \(domain)")
            #endif
            return
        }
        
        URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                if let error = error {
                    #if DEBUG
                    print("Debug - Network error: \(error)")
                    #endif
                    return
                }
                
                if let data = data {
                    self.processSiteData(data: data, domain: domain)
                }
            }
        }.resume()
    }
    
    private func processSiteData(data: Data, domain: String) {
        print("\nDebug - Processing data for domain:", domain)
        
        // בדיקה אם זו הודעת שגיאה
        if let errorString = String(data: data, encoding: .utf8),
           errorString.contains("Site not found") {
            print("Debug - API Response: Site not found")
            
            // שומרים את המידע שהאתר לא נמצא
            let notFoundResponse = APIResponse(
                id: 0,
                URL: domain,
                siteName: "NOT_FOUND",
                siteCategory: "",
                titleParam: "",
                timestamp: Date().timeIntervalSince1970
            )
            storedDataCache[domain] = notFoundResponse
            saveCache()
            
            DispatchQueue.main.async {
                self.hasSiteData = false
            }
            return
        }
        
        do {
            let apiResponse = try JSONDecoder().decode(APIResponse.self, from: data)
            print("Debug - API Response decoded successfully:", apiResponse)
            storedDataCache[domain] = apiResponse
            saveCache()
            DispatchQueue.main.async {
                self.hasSiteData = true
            }
        } catch {
            print("Debug - Error decoding API response:", error)
            DispatchQueue.main.async {
                self.hasSiteData = false
            }
        }
    }
    
    deinit {
        webView.removeObserver(self, forKeyPath: #keyPath(WKWebView.url))
        webView.configuration.userContentController.removeAllUserScripts()
        webView.configuration.userContentController.removeScriptMessageHandler(forName: "keywordFound")
        webView.configuration.userContentController.removeScriptMessageHandler(forName: "keywordNotFound")
        webView.configuration.userContentController.removeScriptMessageHandler(forName: "openUrl")
        webView.configuration.userContentController.removeScriptMessageHandler(forName: "showMessage")
    }
    
    private func handleNotFound(domain: String) {
        let apiResponse = APIResponse(id: 0, URL: domain, siteName: "", siteCategory: "", titleParam: "", timestamp: Date().timeIntervalSince1970)
        storedDataCache[domain] = apiResponse
    }
    
    private func handleFetchError(domain: String) {
        let apiResponse = APIResponse(id: 0, URL: domain, siteName: "", siteCategory: "", titleParam: "", timestamp: Date().timeIntervalSince1970)
        storedDataCache[domain] = apiResponse
    }
    
    private func saveSiteData(_ apiResponse: APIResponse) {
        if let encoded = try? JSONEncoder().encode(apiResponse) {
            UserDefaults.standard.set(encoded, forKey: "storedSiteData")
        }
    }
    
    private func checkStoredData(for domain: String) -> APIResponse? {
        guard let data = UserDefaults.standard.data(forKey: "storedSiteData"),
              let apiResponse = try? JSONDecoder().decode(APIResponse.self, from: data),
              apiResponse.URL == domain else { return nil }
        
        let currentTime = Date().timeIntervalSince1970
        if currentTime - apiResponse.timestamp > 4 * 60 * 60 { // 4 hours
            return nil
        }
        
        return apiResponse
    }
}

struct ComparisonProduct: Codable, Identifiable {
    let id = UUID()
    let name: String
    let price: String
    let site: String
    let url: String
    let urlAff: String
    
    enum CodingKeys: String, CodingKey {
        case name, price, site, url, urlAff
    }
}

struct APIResponse: Codable {
    let id: Int
    let URL: String
    let siteName: String
    let siteCategory: String
    let titleParam: String
    var timestamp: Double
    
    private enum CodingKeys: String, CodingKey {
        case id, URL, siteName, siteCategory, titleParam
    }
    
    init(id: Int, URL: String, siteName: String, siteCategory: String, titleParam: String, timestamp: Double? = nil) {
        self.id = id
        self.URL = URL
        self.siteName = siteName
        self.siteCategory = siteCategory
        self.titleParam = titleParam
        self.timestamp = timestamp ?? Date().timeIntervalSince1970
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        URL = try container.decode(String.self, forKey: .URL)
        siteName = try container.decode(String.self, forKey: .siteName)
        siteCategory = try container.decode(String.self, forKey: .siteCategory)
        titleParam = try container.decode(String.self, forKey: .titleParam)
        timestamp = Date().timeIntervalSince1970
    }
}


extension WebViewModel: WKScriptMessageHandler {
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            switch message.name {
            case "openUrl":
                if let dict = message.body as? [String: String],
                   let urlString = dict["url"],
                   let url = URL(string: urlString) {
                    self.urlString = urlString
                    self.webView.load(URLRequest(url: url))
                    
                    if let title = dict["title"] {
                        self.currentTitleValue = title
                    }
                }
                
            case "showMessage":
                if let dict = message.body as? [String: String],
                   let messageText = dict["message"] {
                    HapticManager.shared.impact(style: .medium)
                }
                
            case "keywordFound":
                guard let domain = getDomainFromURL(webView.url?.absoluteString ?? "") else { return }
                
                if let cachedData = storedDataCache[domain] {
                    let currentTime = Date().timeIntervalSince1970
                    if currentTime - cachedData.timestamp < cacheTimeLimit {
                        self.hasSiteData = true
                        return
                    }
                }
                
                fetchSiteData(domain: domain)
                
            default:
                break
            }
        }
    }
}

struct ComparisonResultView: View {
    let product: ComparisonProduct
    let onLinkTap: (String) -> Void
    
    var body: some View {
        Button(action: {
            print("Debug - Product tapped: \(product.urlAff)")
            onLinkTap(product.urlAff)
        }) {
            VStack(alignment: .leading, spacing: 6) {
                Text(product.name)
                    .font(.system(size: 15, weight: .medium))
                    .lineLimit(2)
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.leading)
                
                HStack(alignment: .center, spacing: 12) {
                    Text(product.price)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.blue)
                    
                    Spacer()
                    
                    Text(product.site)
                        .font(.system(size: 13))
                        .foregroundColor(.gray)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(4)
                }
            }
            .padding(12)
            .background(Color(UIColor.systemBackground))
            .cornerRadius(10)
            .shadow(color: Color.black.opacity(0.1), radius: 3, x: 0, y: 1)
        }
    }
}

struct WebView: UIViewRepresentable {
    @ObservedObject var viewModel: WebViewModel
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    func makeUIView(context: Context) -> WKWebView {
        viewModel.webView.navigationDelegate = context.coordinator
        return viewModel.webView
    }
    
    func updateUIView(_ webView: WKWebView, context: Context) {
        // אין צורך בטעינה מחדש כאן
    }
    
    class Coordinator: NSObject, WKNavigationDelegate {
        var parent: WebView
        
        init(_ parent: WebView) {
            self.parent = parent
        }
        
        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            DispatchQueue.main.async {
                self.parent.viewModel.isLoading = true
            }
        }
        
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            DispatchQueue.main.async {
                self.parent.viewModel.isLoading = false
                self.parent.viewModel.urlString = webView.url?.absoluteString ?? self.parent.viewModel.urlString
                
                if self.parent.viewModel.hasSiteData {
                    print("Debug - Page fully loaded, checking for title")
                    self.parent.viewModel.checkForTitleValue()
                }
            }
        }
        
        // הוספת הפונקציה הזו לטיפול בלינקים
        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            // מדפיס לוג כשמשתמש לוחץ על לינק
            if let url = navigationAction.request.url {
                print("Debug - User clicked link: \(url.absoluteString)")
            }
            
            // תמיד מאפשר את הניווט
            decisionHandler(.allow)
        }
        
        // הוספת טיפול בלינקים שנפתחים בחלון חדש
        func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
            // אם הלינק אמור להיפתח בחלון חדש, נפתח אותו באותו חלון
            if let url = navigationAction.request.url {
                print("Debug - Opening new window link in same window: \(url.absoluteString)")
                webView.load(navigationAction.request)
            }
            return nil
        }
    }
}

private func handleError(_ error: Error) {
    #if DEBUG
    print("Debug - Error occurred: \(error)")
    #endif
}

struct ContentView: View {
    @StateObject private var viewModel = WebViewModel()
    @State private var showToolbar = false
    @State private var showURLField = false
    @State private var currentIndex = 0
    @State private var sortOrder: SortOrder = .none
    
    private var sortedResults: [ComparisonProduct] {
        switch sortOrder {
        case .none:
            return viewModel.comparisonResults
        case .priceAscending:
            return viewModel.comparisonResults.sorted {
                let price1 = Double($0.price.replacingOccurrences(of: "₪", with: "").trimmingCharacters(in: .whitespaces)) ?? 0
                let price2 = Double($1.price.replacingOccurrences(of: "₪", with: "").trimmingCharacters(in: .whitespaces)) ?? 0
                return price1 < price2
            }
        case .priceDescending:
            return viewModel.comparisonResults.sorted {
                let price1 = Double($0.price.replacingOccurrences(of: "₪", with: "").trimmingCharacters(in: .whitespaces)) ?? 0
                let price2 = Double($1.price.replacingOccurrences(of: "₪", with: "").trimmingCharacters(in: .whitespaces)) ?? 0
                return price1 > price2
            }
        }
    }
    
    var body: some View {
        ZStack {
            WebView(viewModel: viewModel)
                .edgesIgnoringSafeArea(.all)
                .simultaneousGesture(
                    DragGesture(minimumDistance: 5)
                        .onChanged { _ in
                            if showToolbar {
                                withAnimation(.easeOut(duration: 0.3)) {
                                    showToolbar = false
                                    showURLField = false
                                }
                            }
                        }
                )
                .onTapGesture {
                    if showToolbar {
                        withAnimation(.easeOut(duration: 0.3)) {
                            showToolbar = false
                            showURLField = false
                        }
                    }
                }
            
            VStack {
                Spacer()
                
                if viewModel.showComparisonResults {
                    VStack(spacing: 0) {
                        // כותרת וכפתורי פעולה
                        HStack {
                            Text("השוואת מחירים")
                                .font(.system(size: 16, weight: .semibold))
                            
                            Spacer()
                            
                            Menu {
                                Button(action: { sortOrder = .none }) {
                                    Label("ללא מיון", systemImage: "arrow.up.arrow.down")
                                }
                                Button(action: { sortOrder = .priceAscending }) {
                                    Label("מחיר: מהזול ליקר", systemImage: "arrow.up")
                                }
                                Button(action: { sortOrder = .priceDescending }) {
                                    Label("מחיר: מהיקר לזול", systemImage: "arrow.down")
                                }
                            } label: {
                                Image(systemName: "arrow.up.arrow.down")
                                    .foregroundColor(.gray)
                            }
                            .padding(.trailing, 8)
                            
                            Button(action: {
                                withAnimation(.easeOut(duration: 0.3)) {
                                    viewModel.showComparisonResults = false
                                }
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.gray)
                                    .font(.system(size: 20))
                            }
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 12)
                        
                        Divider()
                        
                        if !sortedResults.isEmpty {
                            HStack {
                                // כפתור קודם
                                Button(action: {
                                    // נוסיף בדיקת גבולות
                                    if currentIndex > 0 {
                                        withAnimation {
                                            currentIndex -= 1
                                        }
                                    } else {
                                        withAnimation {
                                            currentIndex = sortedResults.count - 1
                                        }
                                    }
                                }) {
                                    Image(systemName: "chevron.left")
                                        .foregroundColor(.gray)
                                        .padding()
                                }
                                
                                // תוצאה נוכחית
                                ComparisonResultView(product: sortedResults[currentIndex]) { url in
                                    if let url = URL(string: url) {
                                        viewModel.webView.load(URLRequest(url: url))
                                        viewModel.showComparisonResults = false
                                    }
                                }
                                .transition(.identity) // שינוי מ-.slide ל-.identity
                                
                                // כפתור הבא
                                Button(action: {
                                    // נוסיף בדיקת גבולות
                                    if currentIndex < sortedResults.count - 1 {
                                        withAnimation {
                                            currentIndex += 1
                                        }
                                    } else {
                                        withAnimation {
                                            currentIndex = 0
                                        }
                                    }
                                }) {
                                    Image(systemName: "chevron.right")
                                        .foregroundColor(.gray)
                                        .padding()
                                }
                            }
                            
                            // אינדיקטור עמוד ומספר תוצאה
                            HStack {
                                Text("\(currentIndex + 1) מתוך \(sortedResults.count)")
                                    .font(.system(size: 12))
                                    .foregroundColor(.gray)
                            }
                            .padding(.vertical, 8)
                        }
                    }
                    .background(Color(UIColor.systemBackground))
                    .cornerRadius(12)
                    .shadow(radius: 3)
                    .padding(.horizontal, 8)
                    .padding(.bottom, 0)
                    .transition(.move(edge: .bottom))
                }
                
                // URL Search Field
                if showURLField {
                    TextField("חיפוש או הזנת כתובת", text: $viewModel.urlString)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .padding(.horizontal)
                        .padding(.bottom, 10)
                        .autocapitalization(.none)
                        .keyboardType(.URL)
                        .submitLabel(.go)
                        .onSubmit {
                            viewModel.loadUrl()
                            withAnimation(.easeOut(duration: 0.3)) {
                                showURLField = false
                            }
                        }
                        .transition(.move(edge: .top))
                }
                
                HStack {
                    Spacer()
                    
                    // Floating Button או Toolbar
                    Group {
                        if showToolbar {
                            // Toolbar
                            HStack(spacing: 20) {
                                Button(action: {
                                    HapticManager.shared.impact(style: .medium)
                                    viewModel.webView.goBack()
                                }) {
                                    Image(systemName: "chevron.left")
                                        .foregroundColor(.white)
                                }

                                Button(action: {
                                    HapticManager.shared.impact(style: .medium)
                                    viewModel.webView.goForward()
                                }) {
                                    Image(systemName: "chevron.right")
                                        .foregroundColor(.white)
                                }

                                Button(action: {
                                    HapticManager.shared.impact(style: .medium)
                                    if let homeUrl = URL(string: "https://yossidisk.github.io/Shamze/shamzeAppHome.html") {
                                        viewModel.webView.load(URLRequest(url: homeUrl))
                                        withAnimation(.easeOut(duration: 0.3)) {
                                            showToolbar = false
                                        }
                                    }
                                }) {
                                    Image(systemName: "house")
                                        .foregroundColor(.white)
                                }
                                
                                Button(action: {
                                    viewModel.webView.reload()
                                }) {
                                    Image(systemName: "arrow.clockwise")
                                        .foregroundColor(.white)
                                }
                            
                                if !viewModel.currentTitleValue.isEmpty {
                                    Text(viewModel.currentTitleValue)
                                        .foregroundColor(.white)
                                        .lineLimit(1)
                                        .frame(maxWidth: .infinity)
                                        .onTapGesture {
                                            UIPasteboard.general.string = viewModel.currentTitleValue
                                        }

                                    Button(action: {
                                        HapticManager.shared.impact(style: .medium)
                                        viewModel.performPriceComparison(query: viewModel.currentTitleValue)
                                        withAnimation(.easeOut(duration: 0.3)) {
                                            viewModel.showComparisonResults.toggle()
                                        }
                                    }) {
                                        Image(systemName: "list.bullet")
                                            .foregroundColor(viewModel.hasComparisonResults ? .green : .white)
                                    }
                                }
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 15)
                                    .fill(Color.black.opacity(0.8))
                            )
                            .transition(.move(edge: .trailing))
                        } else {
                            // Floating Button
                            Button(action: {
                                if viewModel.hasSiteData {
                                    viewModel.checkForTitleValue()
                                }
                                viewModel.hasUnreadResults = false
                                withAnimation(.easeOut(duration: 0.3)) {
                                    showToolbar = true
                                }
                            }) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 15)
                                        .fill(viewModel.hasComparisonResults ? Color.green.opacity(0.8) : Color.black.opacity(0.8))
                                        .frame(width: 50, height: 50)
                                        .overlay(
                                            Image(systemName: "safari")
                                                .foregroundColor(.white)
                                        )
                                    
                                    if viewModel.hasUnreadResults {
                                        Circle()
                                            .fill(Color.red)
                                            .frame(width: 12, height: 12)
                                            .offset(x: 15, y: -15)
                                    }
                                }
                            }
                            .transition(.scale)
                        }
                    }
                }
                .padding(.trailing, 20)
                .padding(.bottom, 50)
            }
        }
    }
}

enum SortOrder {
    case none
    case priceAscending
    case priceDescending
}
