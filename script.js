const compareButton = document.getElementById('compareButton');
const couponButton = document.getElementById('couponButton');
const content = document.getElementById('content');
const searchInput = document.getElementById('searchInput');

// Fetch data from the provided URL
fetch('https://o0rmue7xt0.execute-api.il-central-1.amazonaws.com/dev/sites')
    .then((response) => response.json())
    .then((data) => {
        generateButtons(data);
    })
    .catch((error) => {
        console.error('Error fetching data:', error);
    });

function generateButtons(data) {
    content.innerHTML = ''; // Clear existing buttons
    const compereData = data.filter((item) => item.compareWith.kupon !== 'cupons');
    const kuponData = data.filter((item) => item.compareWith.kupon === 'cupons');

    compareButton.addEventListener('click', () => {
        compareButton.classList.add('selected');
        couponButton.classList.remove('selected');
        displayData(compereData);
    });

    couponButton.addEventListener('click', () => {
        couponButton.classList.add('selected');
        compareButton.classList.remove('selected');
        displayData(kuponData);
    });

    // Initialize with the default data (השוואה list) when the page loads
    displayData(compereData);

    // Listen for changes in the search input field
    searchInput.addEventListener('input', () => {
        const searchText = searchInput.value.toLowerCase().trim();
        const filteredData = data.filter(item =>
            item.siteName.toLowerCase().includes(searchText) ||
            item.URL.toLowerCase().includes(searchText)
        );
        displayData(filteredData);
    });
}

function displayData(data) {
    content.innerHTML = ''; // Clear existing buttons

    data.forEach((item) => {
        // Check if the URL is not an empty string
        if (item.URL) {
            const buttonContainer = document.createElement('div');
            buttonContainer.className = 'button-container';

            const buttonLink = document.createElement('a');
            buttonLink.href = item.URL;
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
