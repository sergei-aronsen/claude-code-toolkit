// Copy buttons
document.querySelectorAll('.copy-btn').forEach(btn => {
  btn.addEventListener('click', () => {
    const code = btn.parentElement.querySelector('code');
    const text = code ? code.innerText : '';
    navigator.clipboard.writeText(text).then(() => {
      const original = btn.innerText;
      btn.innerText = '✓ copied';
      btn.classList.add('copied');
      setTimeout(() => { btn.innerText = original; btn.classList.remove('copied'); }, 1200);
    }).catch(() => {
      btn.innerText = '✗ failed';
      setTimeout(() => { btn.innerText = '📋 copy'; }, 1200);
    });
  });
});

// TOC active-section highlight via IntersectionObserver
const links = document.querySelectorAll('nav.toc a[href^="#"]');
const sections = Array.from(links)
  .map(a => document.getElementById(a.getAttribute('href').slice(1)))
  .filter(Boolean);

if (sections.length) {
  const observer = new IntersectionObserver((entries) => {
    entries.forEach(entry => {
      const id = entry.target.id;
      const link = document.querySelector(`nav.toc a[href="#${id}"]`);
      if (!link) return;
      if (entry.isIntersecting && entry.intersectionRatio > 0.3) {
        document.querySelectorAll('nav.toc a').forEach(a => a.classList.remove('active'));
        link.classList.add('active');
      }
    });
  }, { rootMargin: '-130px 0px -50% 0px', threshold: [0.3, 0.6] });
  sections.forEach(s => observer.observe(s));
}
