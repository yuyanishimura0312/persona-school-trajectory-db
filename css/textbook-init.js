// Theme toggle and reading progress
function toggleTheme() {
  const html = document.documentElement;
  const current = html.getAttribute('data-theme') || 'light';
  const next = current === 'light' ? 'dark' : 'light';
  html.setAttribute('data-theme', next);
  localStorage.setItem('era-talents-theme', next);
  const btn = document.getElementById('themeToggle');
  if (btn) btn.textContent = next === 'light' ? 'DARK' : 'LIGHT';
}

(function() {
  const saved = localStorage.getItem('era-talents-theme') || 'light';
  document.documentElement.setAttribute('data-theme', saved);
  document.addEventListener('DOMContentLoaded', () => {
    const btn = document.getElementById('themeToggle');
    if (btn) btn.textContent = saved === 'light' ? 'DARK' : 'LIGHT';
    const progress = document.getElementById('readingProgress');
    if (progress) {
      window.addEventListener('scroll', () => {
        const h = document.documentElement;
        const scrollPct = (h.scrollTop / (h.scrollHeight - h.clientHeight)) * 100;
        progress.style.width = scrollPct + '%';
      });
    }
  });
})();
