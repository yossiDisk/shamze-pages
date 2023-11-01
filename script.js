const compareButton = document.getElementById('compareButton');
const couponButton = document.getElementById('couponButton');
const content = document.getElementById('content');

let currentData = [];

compareButton.addEventListener('click', () => {
    compareButton.classList.add('selected');
    couponButton.classList.remove('selected');
    generateButtons(compereData); // Use compereData from json.js
});

couponButton.addEventListener('click', () => {
    couponButton.classList.add('selected');
    compareButton.classList.remove('selected');
    generateButtons(kuponData); // Use kuponData from json.js
});

function generateButtons(data) {
    content.innerHTML = ''; // Clear existing buttons

    data.forEach((item) => {
        // Check if the URL is not an empty string
        if (item.URL || (item.link && item.link[0])) {
            const buttonContainer = document.createElement('div');
            buttonContainer.className = 'button-container';

            const buttonLink = document.createElement('a');
            buttonLink.href = item.LINK || item.link[0];
            buttonLink.target = '_blank'; // Open in a new tab
            buttonLink.className = 'button-link';

            const button = document.createElement('button');
            button.textContent = item.site || item.name;
            button.className = 'button';

            buttonLink.appendChild(button);
            buttonContainer.appendChild(buttonLink);
            content.appendChild(buttonContainer);
        }
    });
}

// Initialize with the default data (השוואה list) when the page loads
generateButtons(kuponData); // Use kuponData from json.js
