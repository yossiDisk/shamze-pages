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




document.addEventListener('DOMContentLoaded', () => {
    const urlParams = new URLSearchParams(window.location.search);
    const siteId = urlParams.get('siteId');
    const query = urlParams.get('query');

    if (query) {
        document.getElementById('page-title').innerText = query;
        document.getElementById('header-title').innerText = query;
    }

    if (siteId && query) {
        const apiUrl = `https://o0rmue7xt0.execute-api.il-central-1.amazonaws.com/dev/items?siteId=${siteId}&query=${query}`;
        
        fetch(apiUrl)
            .then(response => response.json())
            .then(data => {
                populateTable(data);
                addSortAndFilter(data);
            })
            .catch(error => console.error('Error fetching data:', error));
    }
});

function populateTable(data) {
    const tbody = document.querySelector('#data-table tbody');
    tbody.innerHTML = '';
    data.forEach(item => {
        const row = document.createElement('tr');
        row.innerHTML = `
            <td>${item.name}</td>
            <td>${item.price}</td>
            <td><a href="${item.URL}" target="_blank">Link</a></td>
            <td><img src="${item.imageURL}" alt="${item.name}" width="50"></td>
        `;
        tbody.appendChild(row);
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
    filterInput.addEventListener('input', () => {
        const filteredData = filterData(data, filterInput.value);
        populateTable(filteredData);
    });

    const priceFromInput = document.getElementById('priceFrom');
    const priceToInput = document.getElementById('priceTo');

    priceFromInput.addEventListener('input', () => {
        const filteredData = filterDataByPrice(data, priceFromInput.value, priceToInput.value);
        populateTable(filteredData);
    });

    priceToInput.addEventListener('input', () => {
        const filteredData = filterDataByPrice(data, priceFromInput.value, priceToInput.value);
        populateTable(filteredData);
    });
}

function sortData(data, key, order) {
    return [...data].sort((a, b) => {
        if (key === 'price') {
            return order === 'asc' ? parseFloat(a[key]) - parseFloat(b[key]) : parseFloat(b[key]) - parseFloat(a[key]);
        } else if (key === 'name' || key === 'URL' || key === 'imageURL') {
            return order === 'asc' ? a[key].localeCompare(b[key]) : b[key].localeCompare(a[key]);
        }
    });
}

function filterData(data, keyword) {
    return data.filter(item => item.name.toLowerCase().includes(keyword.toLowerCase()));
}

function filterDataByPrice(data, fromPrice, toPrice) {
    return data.filter(item => {
        const price = parseFloat(item.price);
        if (fromPrice && price < fromPrice) {
            return false;
        }
        if (toPrice && price > toPrice) {
            return false;
        }
        return true;
    });
}
