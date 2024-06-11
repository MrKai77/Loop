document.addEventListener('DOMContentLoaded', () => {
    const body = document.body;
    const themeToggleBtn = document.getElementById('theme-toggle');
    const iconSun = themeToggleBtn.querySelector('.sun');
    const iconMoon = themeToggleBtn.querySelector('.moon');

    const updateTheme = (theme) => {
        body.dataset.theme = theme;
        localStorage.setItem('theme', theme);
        iconSun.style.display = theme === 'dark' ? 'none' : 'block';
        iconMoon.style.display = theme === 'dark' ? 'block' : 'none';
    };

    const toggleTheme = () => {
        const newTheme = body.dataset.theme === 'dark' ? 'light' : 'dark';
        updateTheme(newTheme);
    };

    themeToggleBtn.addEventListener('click', toggleTheme);

    const preferredTheme = localStorage.getItem('theme') || (window.matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light');
    updateTheme(preferredTheme);
});
