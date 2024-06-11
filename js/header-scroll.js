// This will add the glass effect when the user scrolls
window.addEventListener('scroll', () => {
    document.querySelector('header')?.classList.toggle('glass-effect', window.scrollY > 0);
});

// Add code for the download button
document.addEventListener('DOMContentLoaded', () => {
    document.querySelector('.download')?.addEventListener('click', () => window.location.href = 'https://github.com/MrKai77/Loop/releases/latest/download/Loop.zip');
});