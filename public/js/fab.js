document.addEventListener('DOMContentLoaded', () => {
  const fab    = document.getElementById('fab');
  if (!fab) return;

  const toggle = document.getElementById('fab-toggle');
  const bar    = document.getElementById('fab-bar');
  const closeB = fab.querySelector('.fab-close');

  const mqMobile = window.matchMedia('(max-width: 768px)');

  const open  = () => {
    fab.classList.add('open');
    toggle?.setAttribute('aria-expanded','true');
    bar?.setAttribute('aria-hidden','false');
  };
  const close = () => {
    fab.classList.remove('open');
    toggle?.setAttribute('aria-expanded','false');
    bar?.setAttribute('aria-hidden','true');
  };

  toggle?.addEventListener('click', (e) => {
    e.stopPropagation();
    fab.classList.contains('open') ? close() : open();
  });

  closeB?.addEventListener('click', close);

  document.addEventListener('click', (e) => {
    if (mqMobile.matches) return;
    if (!fab.contains(e.target)) close();
  });

  document.addEventListener('keydown', (e) => {
    if (e.key === 'Escape' && !mqMobile.matches) close();
  });

  if (mqMobile.matches) open();
});
