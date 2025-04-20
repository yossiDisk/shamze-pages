document.addEventListener('DOMContentLoaded', () => {
    const urlParams = new URLSearchParams(window.location.search);
    const siteId = urlParams.get('siteId');
    const query = urlParams.get('query');
    const compareButton = document.getElementById('compareButton');
    const couponButton = document.getElementById('couponButton');
    const content = document.getElementById('content');
    const searchInput = document.getElementById('searchInput');

    if (query) {
        document.getElementById('page-title').innerText = query;
        document.getElementById('header-title').innerText = query;
    }
    

    if (siteId && query) {
        const apiUrl = `https://o0rmue7xt0.execute-api.il-central-1.amazonaws.com/dev/items?siteId=${siteId}&query=${query}`;
        
        fetch(apiUrl)
            .then(response => response.json())
            .then(data => {
                let formattedData = [];
                if (isOldFormat(data)) {
                    formattedData = formatOldData(data);
                } else {
                    formattedData = formatNewData(data);
                }
                window.allData = formattedData; // Store all data globally
                const uniqueData = getUniqueData(formattedData);
                populateTable(uniqueData);
                addSortAndFilter(uniqueData);
            })
            .catch(error => console.error('Error fetching data:', error));
    }

    fetch('https://o0rmue7xt0.execute-api.il-central-1.amazonaws.com/dev/sites')
        .then((response) => response.json())
        .then((data) => {
            generateButtons(data);
        })
        .catch((error) => {
            console.error('Error fetching data:', error);
        });

    function generateButtons(data) {
        if (content) {
            content.innerHTML = ''; // Clear existing buttons
            const compereData = data.filter((item) => item.compareWith.kupon !== 'cupons');
            const kuponData = data.filter((item) => item.compareWith.kupon === 'cupons');
    
            if (compareButton) {
                compareButton.addEventListener('click', () => {
                    compareButton.classList.add('selected');
                    if (couponButton) couponButton.classList.remove('selected');
                    displayData(compereData);
                });
            }
    
            if (couponButton) {
                couponButton.addEventListener('click', () => {
                    couponButton.classList.add('selected');
                    if (compareButton) compareButton.classList.remove('selected');
                    displayData(kuponData);
                });
            }
    
            // Initialize with the default data (השוואה list) when the page loads
            displayData(compereData);
    
            // Listen for changes in the search input field
            if (searchInput) {
                searchInput.addEventListener('input', () => {
                    const searchText = searchInput.value.toLowerCase().trim();
                    const filteredData = data.filter(item =>
                        item.siteName.toLowerCase().includes(searchText) ||
                        item.URL.toLowerCase().includes(searchText)
                    );
                    displayData(filteredData);
                });
            }
        }
    }

    function displayData(data) {
        if (content) {
            content.innerHTML = ''; // Clear existing buttons
            data.forEach((item) => {
                // Check if the URL is not an empty string
                if (item.URL) {
                    const buttonContainer = document.createElement('div');
                    buttonContainer.className = 'button-container';
    
                    const buttonLink = document.createElement('a');
                    buttonLink.href = item.affLink;
                    buttonLink.target = '_blank'; // Open in a new tab
                    buttonLink.className = 'button-link';
    
                    const button = document.createElement('button');
                    button.textContent = item.siteName || item.site;
                    button.className = 'button';
    
                    buttonLink.appendChild(button);
                    buttonContainer.appendChild(buttonLink);
                    content.appendChild(buttonContainer);
                }
            });
        }
    }

    function isOldFormat(data) {
        return data[0] && data[0].hasOwnProperty('ItemCode');
    }

    function formatOldData(data) {
        return data.map(item => ({
            id: item.ItemCode,
            createdAt: item.PriceUpdateDate,
            name: cleanName(item.ItemName || item.ManufacturerItemDescription),
            priceILS: parseFloat(item.ItemPrice),
            url: item.URL,
            website: item.Super
        }));
    }

    function formatNewData(data) {
        return data.map(item => ({
            id: item.id,
            createdAt: item.createdAt,
            name: cleanName(item.name),
            priceILS: parseFloat(item.priceILS),
            url: item.url,
            website: item.website
        }));
    }

    function getUniqueData(data) {
        const uniqueItems = [];
        const itemMap = new Map();
    
        data.forEach(item => {
            const key = `${item.name}-${item.website}`;
            if (!itemMap.has(key)) {
                itemMap.set(key, []);
            }
            itemMap.get(key).push(item);
        });
    
        itemMap.forEach(items => {
            uniqueItems.push(items[0]);
        });
    
        return uniqueItems;
    }

    function createItemMap(data) {
        const itemMap = new Map();
    
        data.forEach(item => {
            const key = `${item.name}-${item.website}`;
            if (!itemMap.has(key)) {
                itemMap.set(key, []);
            }
            itemMap.get(key).push(item);
        });
    
        return itemMap;
    }

function populateTable(data) {
    const tbody = document.querySelector('#data-table tbody');
    if (tbody) {
        tbody.innerHTML = '';
        const itemMap = createItemMap(getAllData());

        data.forEach(item => {
            const row = document.createElement('tr');
            const key = `${item.name}-${item.website}`;
            const itemHistory = itemMap.get(key);
            const itemCount = itemHistory.length;
            const buttonDisabled = itemCount <= 1 ? 'disabled' : '';
            
            itemHistory.sort((a, b) => new Date(b.createdAt) - new Date(a.createdAt));
            
            const mostRecentItem = itemHistory[0];
            const insight = getInsight(itemHistory);
            const domainName = extractDomain(mostRecentItem.url);

            row.innerHTML = `
                <td>${mostRecentItem.name}</td>
                <td>${mostRecentItem.priceILS}</td>
                <td><a href="${mostRecentItem.url}" target="_blank" title="${mostRecentItem.url}">Link</a></td>
                <td title="${mostRecentItem.url}">${domainName}</td>
                <td>${new Date(mostRecentItem.createdAt).toLocaleString()}</td>
                <td><button class="price-history-btn" data-name="${mostRecentItem.name}" data-website="${domainName}" ${buttonDisabled}>הסטוריית מחירים</button></td>
                <td>${insight}</td>
            `;
            tbody.appendChild(row);
        });
    
            document.querySelectorAll('.price-history-btn').forEach(button => {
                button.addEventListener('click', event => {
                    const name = event.target.dataset.name;
                    const website = event.target.dataset.website;
                    if (!event.target.disabled) {
                        displayPriceHistory(name, website);
                    }
                });
            });
        }
    }

    function extractDomain(url) {
        let domain;
        try {
            domain = new URL(url).hostname;
        } catch (e) {
            domain = url;
        }
        return domain.replace(/^www\./, '');
    }

    function getInsight(itemHistory) {
        if (itemHistory.length < 2) return '';
    
        // Sort by date, most recent first
        itemHistory.sort((a, b) => new Date(b.createdAt) - new Date(a.createdAt));
    
        const currentPrice = parseFloat(itemHistory[0].priceILS);
        const previousPrice = parseFloat(itemHistory[1].priceILS);
    
        if (isNaN(currentPrice) || isNaN(previousPrice)) return '';
    
        const priceDifference = currentPrice - previousPrice;
        const percentageChange = (priceDifference / previousPrice) * 100;
    
        if (percentageChange <= -20) {
            return 'ירידת מחיר חדה';
        } else if (percentageChange >= 20) {
            return 'עליית מחיר חדה';
        } else if (percentageChange < 0) {
            return 'ירידת מחיר';
        } else if (percentageChange > 0) {
            return 'עליית מחיר';
        } else {
            return '';
        }
    }

    function createPriceHistoryGraph(data) {
        const ctx = document.getElementById('priceHistoryChart').getContext('2d');
        
        if (window.priceHistoryChart instanceof Chart) {
            window.priceHistoryChart.destroy();
        }
        
        const chartData = data.map(item => ({
            x: new Date(item.createdAt),
            y: parseFloat(item.priceILS)
        })).reverse();
    
        window.priceHistoryChart = new Chart(ctx, {
            type: 'line',
            data: {
                datasets: [{
                    label: 'Price History',
                    data: chartData,
                    borderColor: 'rgb(75, 192, 192)',
                    tension: 0.1
                }]
            },
            options: {
                responsive: true,
                aspectRatio: 2, // This should match the aspect-ratio in CSS
                scales: {
                    x: {
                        type: 'time',
                        time: {
                            unit: 'day'
                        },
                        title: {
                            display: true,
                            text: 'Date'
                        }
                    },
                    y: {
                        title: {
                            display: true,
                            text: 'Price (ILS)'
                        },
                        beginAtZero: false
                    }
                },
                plugins: {
                    legend: {
                        display: false // Hide the legend if not needed
                    }
                }
            }
        });
    }

    function addSortAndFilter(data) {
        const headers = document.querySelectorAll('#data-table th');
        headers.forEach(header => {
            header.addEventListener('click', () => {
                const column = header.dataset.column;
                const order = header.dataset.order === 'desc' ? 'asc' : 'desc';
                header.dataset.order = order;
                const sortedData = sortData(data, column, order);
                populateTable(sortedData);
            });
        });
    
        const filterInput = document.getElementById('filterKey');
        if (filterInput) {
            filterInput.addEventListener('input', () => {
                const filteredData = filterData(data, filterInput.value);
                populateTable(filteredData);
            });
        }
    
        const priceFromInput = document.getElementById('priceFrom');
        const priceToInput = document.getElementById('priceTo');
        const filterWebsiteInput = document.getElementById('filterWebsite');
    
        if (priceFromInput) {
            priceFromInput.addEventListener('input', () => {
                const filteredData = filterDataByPrice(data, priceFromInput.value, priceToInput.value, filterWebsiteInput.value);
                populateTable(filteredData);
            });
        }
    
        if (priceToInput) {
            priceToInput.addEventListener('input', () => {
                const filteredData = filterDataByPrice(data, priceFromInput.value, priceToInput.value, filterWebsiteInput.value);
                populateTable(filteredData);
            });
        }
    
        if (filterWebsiteInput) {
            filterWebsiteInput.addEventListener('input', () => {
                const filteredData = filterDataByPrice(data, priceFromInput.value, priceToInput.value, filterWebsiteInput.value);
                populateTable(filteredData);
            });
        }
    }

    function sortData(data, key, order) {
        return [...data].sort((a, b) => {
            if (key === 'priceILS') {
                return order === 'asc' ? parseFloat(a[key]) - parseFloat(b[key]) : parseFloat(b[key]) - parseFloat(a[key]);
            } else if (key === 'name' || key === 'url' || key === 'website') {
                return order === 'asc' ? a[key].localeCompare(b[key]) : b[key].localeCompare(a[key]);
            } else if (key === 'createdAt') {
                return order === 'asc' ? new Date(a[key]) - new Date(b[key]) : new Date(b[key]) - new Date(a[key]);
            }
        });
    }

    function filterData(data, keyword) {
        return data.filter(item => item.name.toLowerCase().includes(keyword.toLowerCase()));
    }

    function filterDataByPrice(data, fromPrice, toPrice, website) {
        return data.filter(item => {
            const price = parseFloat(item.priceILS);
            const matchesWebsite = !website || item.website.toLowerCase().includes(website.toLowerCase());
            const matchesPriceFrom = !fromPrice || price >= parseFloat(fromPrice);
            const matchesPriceTo = !toPrice || price <= parseFloat(toPrice);
            return matchesWebsite && matchesPriceFrom && matchesPriceTo;
        });
    }


    function displayPriceHistory(name, website) {
        const allData = getAllData();
        const historyData = allData.filter(item => item.name === name && item.website === website);
        const sortedHistoryData = sortData(historyData, 'createdAt', 'desc');
        const tbody = document.querySelector('#history-table tbody');
        if (tbody) {
            tbody.innerHTML = '';
            sortedHistoryData.forEach(item => {
                const row = document.createElement('tr');
                row.innerHTML = `
                    <td>${item.name}</td>
                    <td>${item.priceILS}</td>
                    <td><a href="${item.url}" target="_blank" rel="noopener noreferrer">Link</a></td>
                    <td>${item.website}</td>
                    <td>${new Date(item.createdAt).toLocaleString()}</td>
                `;
                tbody.appendChild(row);
            });
        }
        const modal = document.getElementById('priceHistoryModal');
        if (modal) {
            modal.style.display = 'block';
        }
        
        // Add graph
        createPriceHistoryGraph(sortedHistoryData);
    }

    function getAllData() {
        return window.allData || [];
    }

    function cleanName(name) {
        return name.replace(/"/g, "'");
    }

    document.querySelector('.close').addEventListener('click', () => {
        const modal = document.getElementById('priceHistoryModal');
        if (modal) {
            modal.style.display = 'none';
        }
    });

    window.onclick = event => {
        const modal = document.getElementById('priceHistoryModal');
        if (event.target === modal) {
            modal.style.display = 'none';
        }
    };
});
