/* Chakra Architecture — Shared Navigation */
(function () {
  'use strict';

  const REPO = 'https://github.com/IMGIITRoorkee/chakra-docker';
  const PAGES_BASE = './';

  const NAV = [
    { label: 'Home', href: 'index.html', dot: '#f0a030' },
    { section: 'Architecture' },
    { label: 'System Overview', href: 'system-overview.html', dot: '#5ba4e6' },
    { label: 'Two-Server Setup', href: 'two-servers.html', dot: '#9b7be8' },
    { label: 'Image Lifecycle', href: 'image-lifecycle.html', dot: '#e88c3e' },
    { label: 'Deployment Guide', href: 'deployment.html', dot: '#4cc98a' },
    { section: 'Components' },
    { label: 'Backend (Django)', href: 'backend.html', dot: '#4cc98a', sub: true },
    { label: 'Transpiler (Core)', href: 'transpiler.html', dot: '#e85c5c', sub: true },
    { label: 'Frontend (Next.js)', href: 'frontend.html', dot: '#5ba4e6', sub: true },
    { label: 'ConfMan', href: 'confman.html', dot: '#9b7be8', sub: true },
    { section: 'Operations' },
    { label: 'Nginx & Routing', href: 'nginx.html', dot: '#4cc98a' },
    { label: 'lsyncd & Sync', href: 'lsyncd.html', dot: '#f0a030' },
    { label: 'Backups & S3', href: 'backups.html', dot: '#44c8cc' },
  ];

  /* ── Search index ── */
  let searchIndex = null;
  let searchReady = false;
  let selectedIdx = -1;

  function buildIndex() {
    const pages = NAV.filter(n => n.href);
    return Promise.all(pages.map(item => {
      const url = PAGES_BASE + item.href;
      return fetch(url).then(r => r.ok ? r.text() : '').then(rawHtml => {
        const doc = new DOMParser().parseFromString(rawHtml, 'text/html');
        doc.querySelectorAll('script, style, nav, .sidebar, .breadcrumb').forEach(el => el.remove());
        const headings = Array.from(doc.querySelectorAll('h1, h2, h3, h4')).map(h => h.textContent.trim());
        const text = (doc.body ? doc.body.textContent : '').replace(/\s+/g, ' ').trim();
        return { title: item.label, href: item.href, headings, text };
      }).catch(() => ({ title: item.label, href: item.href, headings: [], text: '' }));
    }));
  }

  function searchDocs(query, index) {
    const q = query.toLowerCase().trim();
    if (!q) return [];
    const tokens = q.split(/\s+/).filter(Boolean);
    const scored = [];
    for (const page of index) {
      let score = 0;
      const tl = page.title.toLowerCase();
      const hl = page.headings.join(' ').toLowerCase();
      const xl = page.text.toLowerCase();
      for (const t of tokens) {
        if (tl.includes(t)) score += 10;
        if (hl.includes(t)) score += 5;
        if (xl.includes(t)) score += 1;
      }
      if (score > 0) scored.push({ ...page, score });
    }
    scored.sort((a, b) => b.score - a.score);
    return scored.slice(0, 12);
  }

  function escText(s) { return s.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;'); }

  function getExcerpt(text, query) {
    const tokens = query.toLowerCase().trim().split(/\s+/).filter(Boolean);
    const lower = text.toLowerCase();
    let best = -1;
    for (const t of tokens) { const i = lower.indexOf(t); if (i !== -1) { best = i; break; } }
    if (best === -1) return '';
    const s = Math.max(0, best - 60), e = Math.min(text.length, best + 140);
    let slice = escText((s > 0 ? '...' : '') + text.slice(s, e).trim() + (e < text.length ? '...' : ''));
    for (const t of tokens) {
      slice = slice.replace(new RegExp('(' + t.replace(/[.*+?^${}()|[\]\\]/g, '\\$&') + ')', 'gi'), '<mark>$1</mark>');
    }
    return slice;
  }

  /* ── Search overlay ── */
  function createSearchOverlay() {
    const o = document.createElement('div');
    o.className = 'search-overlay'; o.id = 'search-overlay';

    const modal = document.createElement('div');
    modal.className = 'search-modal';

    // Input row
    const inputRow = document.createElement('div');
    inputRow.className = 'search-input-row';
    const searchSvg = document.createElementNS('http://www.w3.org/2000/svg', 'svg');
    searchSvg.setAttribute('class', 'search-icon');
    searchSvg.setAttribute('width', '16'); searchSvg.setAttribute('height', '16');
    searchSvg.setAttribute('viewBox', '0 0 24 24'); searchSvg.setAttribute('fill', 'none');
    searchSvg.setAttribute('stroke', 'currentColor'); searchSvg.setAttribute('stroke-width', '2');
    const circle = document.createElementNS('http://www.w3.org/2000/svg', 'circle');
    circle.setAttribute('cx', '11'); circle.setAttribute('cy', '11'); circle.setAttribute('r', '8');
    const line = document.createElementNS('http://www.w3.org/2000/svg', 'line');
    line.setAttribute('x1', '21'); line.setAttribute('y1', '21'); line.setAttribute('x2', '16.65'); line.setAttribute('y2', '16.65');
    searchSvg.appendChild(circle); searchSvg.appendChild(line);

    const input = document.createElement('input');
    input.id = 'search-input'; input.type = 'text';
    input.placeholder = 'Search architecture docs\u2026';
    input.autocomplete = 'off'; input.spellcheck = false;

    const escHint = document.createElement('span');
    escHint.className = 'search-esc-hint'; escHint.textContent = 'ESC';

    inputRow.appendChild(searchSvg);
    inputRow.appendChild(input);
    inputRow.appendChild(escHint);

    // Results
    const results = document.createElement('div');
    results.className = 'search-results'; results.id = 'search-results';
    const hint = document.createElement('div');
    hint.className = 'search-hint'; hint.textContent = 'Type to search across all pages. Tip: \u2318K anytime.';
    results.appendChild(hint);

    // Footer
    const footer = document.createElement('div');
    footer.className = 'search-footer-bar';
    footer.textContent = '\u2191\u2193 navigate  \u21b5 open  esc close';

    modal.appendChild(inputRow);
    modal.appendChild(results);
    modal.appendChild(footer);
    o.appendChild(modal);
    document.body.appendChild(o);

    o.addEventListener('click', e => { if (e.target === o) closeSearch(); });

    let debounce = null;
    input.addEventListener('input', () => { clearTimeout(debounce); debounce = setTimeout(() => runSearch(input.value), 150); });
    input.addEventListener('keydown', e => {
      if (e.key === 'ArrowDown') { e.preventDefault(); moveSelection(1); }
      else if (e.key === 'ArrowUp') { e.preventDefault(); moveSelection(-1); }
      else if (e.key === 'Enter') { e.preventDefault(); const items = document.querySelectorAll('.search-result-item'); if (items[selectedIdx]) items[selectedIdx].click(); }
      else if (e.key === 'Escape') closeSearch();
    });
  }

  function runSearch(query) {
    const r = document.getElementById('search-results'); if (!r) return;
    selectedIdx = -1;
    // Clear previous results safely
    while (r.firstChild) r.removeChild(r.firstChild);

    if (!query.trim() || query.trim().length < 2) {
      const h = document.createElement('div'); h.className = 'search-hint'; h.textContent = 'Type to search\u2026';
      r.appendChild(h); return;
    }
    if (!searchReady) {
      const h = document.createElement('div'); h.className = 'search-hint'; h.textContent = 'Building index\u2026';
      r.appendChild(h); return;
    }
    const m = searchDocs(query, searchIndex);
    if (!m.length) {
      const h = document.createElement('div'); h.className = 'search-hint';
      h.textContent = 'No results for "' + query + '"';
      r.appendChild(h); return;
    }
    m.forEach((p, i) => {
      const a = document.createElement('a');
      a.className = 'search-result-item' + (i === 0 ? ' selected' : '');
      a.href = PAGES_BASE + p.href;
      const title = document.createElement('div');
      title.className = 'search-result-title';
      title.textContent = p.title;
      a.appendChild(title);
      const excerpt = getExcerpt(p.text, query);
      if (excerpt) {
        const ex = document.createElement('p');
        ex.className = 'search-result-excerpt';
        ex.textContent = p.text.slice(0, 200);
        a.appendChild(ex);
      }
      r.appendChild(a);
    });
    selectedIdx = 0;
  }

  function moveSelection(dir) {
    const items = document.querySelectorAll('.search-result-item');
    if (!items.length) return;
    items.forEach(i => i.classList.remove('selected'));
    selectedIdx = (selectedIdx + dir + items.length) % items.length;
    items[selectedIdx].classList.add('selected');
    items[selectedIdx].scrollIntoView({ block: 'nearest' });
  }

  function openSearch() {
    const o = document.getElementById('search-overlay'); if (!o) return;
    o.classList.add('open');
    const input = o.querySelector('#search-input'); input.value = ''; input.focus(); runSearch('');
    if (!searchReady && !searchIndex) buildIndex().then(idx => { searchIndex = idx; searchReady = true; });
  }
  function closeSearch() { const o = document.getElementById('search-overlay'); if (o) o.classList.remove('open'); }

  /* ── Sidebar builder ── */
  function currentPage() {
    const p = location.pathname;
    for (const item of NAV) {
      if (!item.href) continue;
      if (p.endsWith(item.href) || p.endsWith('/' + item.href)) return item.href;
    }
    if (p.endsWith('/') || p.endsWith('/architecture/') || p.endsWith('/architecture')) return 'index.html';
    return '';
  }

  function buildSidebar() {
    const sb = document.createElement('nav');
    sb.className = 'sidebar'; sb.id = 'sidebar';
    const cur = currentPage();

    // Logo section
    const logoDiv = document.createElement('div'); logoDiv.className = 'sidebar-logo';
    const logoInner = document.createElement('div'); logoInner.className = 'sidebar-logo-inner';

    // Chakra wheel SVG icon
    const svgNS = 'http://www.w3.org/2000/svg';
    const logoSvg = document.createElementNS(svgNS, 'svg');
    logoSvg.setAttribute('class', 'sidebar-logo-icon');
    logoSvg.setAttribute('viewBox', '0 0 32 32');
    logoSvg.setAttribute('fill', 'none');
    [{tag:'circle',a:{cx:16,cy:16,r:14,stroke:'#f0a030','stroke-width':2.5,opacity:0.3}},
     {tag:'circle',a:{cx:16,cy:16,r:8,stroke:'#f0a030','stroke-width':2}},
     {tag:'circle',a:{cx:16,cy:16,r:2.5,fill:'#f0a030'}},
     {tag:'line',a:{x1:16,y1:2,x2:16,y2:8,stroke:'#f0a030','stroke-width':1.5,'stroke-linecap':'round'}},
     {tag:'line',a:{x1:16,y1:24,x2:16,y2:30,stroke:'#f0a030','stroke-width':1.5,'stroke-linecap':'round'}},
     {tag:'line',a:{x1:2,y1:16,x2:8,y2:16,stroke:'#f0a030','stroke-width':1.5,'stroke-linecap':'round'}},
     {tag:'line',a:{x1:24,y1:16,x2:30,y2:16,stroke:'#f0a030','stroke-width':1.5,'stroke-linecap':'round'}}
    ].forEach(({tag,a})=>{const el=document.createElementNS(svgNS,tag);Object.entries(a).forEach(([k,v])=>el.setAttribute(k,String(v)));logoSvg.appendChild(el);});

    const logoText = document.createElement('div'); logoText.className = 'sidebar-logo-text';
    const strong = document.createElement('strong'); strong.textContent = 'Chakra ';
    const em = document.createElement('em'); em.textContent = 'CMS'; strong.appendChild(em);
    const sub = document.createElement('span'); sub.textContent = 'Architecture Reference';
    logoText.appendChild(strong); logoText.appendChild(sub);
    logoInner.appendChild(logoSvg); logoInner.appendChild(logoText);
    logoDiv.appendChild(logoInner);

    // Theme toggle
    const themeBtn = document.createElement('button');
    themeBtn.className = 'theme-toggle'; themeBtn.textContent = '\u263e'; themeBtn.title = 'Toggle theme';
    themeBtn.onclick = () => {
      const isLight = document.documentElement.classList.toggle('light');
      themeBtn.textContent = isLight ? '\u2600' : '\u263e';
      try { localStorage.setItem('chakra-arch-theme', isLight ? 'light' : 'dark'); } catch(e) {}
    };
    logoDiv.appendChild(themeBtn);
    try { if (localStorage.getItem('chakra-arch-theme') === 'light') { document.documentElement.classList.add('light'); themeBtn.textContent = '\u2600'; } } catch(e) {}

    // Search button
    const searchDiv = document.createElement('div'); searchDiv.className = 'sidebar-search';
    const searchBtn = document.createElement('button'); searchBtn.id = 'open-search'; searchBtn.className = 'docs-search-btn';
    const searchIcon2 = document.createElementNS(svgNS, 'svg');
    searchIcon2.setAttribute('width', '14'); searchIcon2.setAttribute('height', '14');
    searchIcon2.setAttribute('viewBox', '0 0 24 24'); searchIcon2.setAttribute('fill', 'none');
    searchIcon2.setAttribute('stroke', 'currentColor'); searchIcon2.setAttribute('stroke-width', '2');
    const c2 = document.createElementNS(svgNS, 'circle'); c2.setAttribute('cx','11'); c2.setAttribute('cy','11'); c2.setAttribute('r','8');
    const l2 = document.createElementNS(svgNS, 'line'); l2.setAttribute('x1','21'); l2.setAttribute('y1','21'); l2.setAttribute('x2','16.65'); l2.setAttribute('y2','16.65');
    searchIcon2.appendChild(c2); searchIcon2.appendChild(l2);
    const searchSpan = document.createElement('span'); searchSpan.textContent = 'Search docs\u2026';
    const searchKbd = document.createElement('kbd'); searchKbd.textContent = '\u2318K';
    searchBtn.appendChild(searchIcon2); searchBtn.appendChild(searchSpan); searchBtn.appendChild(searchKbd);
    searchDiv.appendChild(searchBtn);
    searchBtn.addEventListener('click', openSearch);

    // Nav links
    const navDiv = document.createElement('div'); navDiv.className = 'sidebar-nav'; navDiv.id = 'nav-links';
    for (const item of NAV) {
      if (item.section) {
        const s = document.createElement('div'); s.className = 'nav-section'; s.textContent = item.section;
        navDiv.appendChild(s); continue;
      }
      const a = document.createElement('a');
      a.className = 'nav-link' + (item.sub ? ' sub' : '') + (item.href === cur ? ' active' : '');
      a.href = PAGES_BASE + item.href;
      const dot = document.createElement('span'); dot.className = 'nav-dot'; dot.style.background = item.dot;
      a.appendChild(dot);
      a.appendChild(document.createTextNode(item.label));
      navDiv.appendChild(a);
    }

    // Footer
    const footerDiv = document.createElement('div'); footerDiv.className = 'sidebar-footer';
    const brand = document.createElement('div'); brand.className = 'sidebar-footer-brand'; brand.textContent = 'IIT Roorkee \u00b7 IMG';
    const footerLinks = document.createElement('div'); footerLinks.className = 'sidebar-footer-links';
    const ghLink = document.createElement('a'); ghLink.href = REPO; ghLink.target = '_blank'; ghLink.rel = 'noopener'; ghLink.textContent = 'GitHub';
    const siteLink = document.createElement('a'); siteLink.href = 'https://chakra.channeli.in'; siteLink.target = '_blank'; siteLink.rel = 'noopener'; siteLink.textContent = 'Live Site';
    footerLinks.appendChild(ghLink); footerLinks.appendChild(siteLink);
    footerDiv.appendChild(brand); footerDiv.appendChild(footerLinks);

    // Assemble sidebar
    sb.appendChild(logoDiv);
    sb.appendChild(searchDiv);
    sb.appendChild(navDiv);
    sb.appendChild(footerDiv);
    document.body.prepend(sb);

    // Mobile toggle
    const btn = document.createElement('button'); btn.className = 'menu-toggle'; btn.textContent = '\u2630';
    btn.onclick = () => sb.classList.toggle('open');
    document.body.prepend(btn);
  }

  /* ── TOC ── */
  function buildToc() {
    const content = document.querySelector('.content'); if (!content) return;
    const headings = content.querySelectorAll('h2, h3');
    if (headings.length < 3) return;
    headings.forEach((h, i) => { if (!h.id) h.id = 'toc-' + i + '-' + h.textContent.trim().toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/-+$/, ''); });
    const toc = document.createElement('aside'); toc.className = 'toc-sidebar';
    const tocTitle = document.createElement('div'); tocTitle.className = 'toc-title'; tocTitle.textContent = 'On this page';
    toc.appendChild(tocTitle);
    headings.forEach(h => {
      const a = document.createElement('a');
      a.className = 'toc-link' + (h.tagName === 'H3' ? ' toc-h3' : '');
      a.href = '#' + h.id; a.textContent = h.textContent.trim();
      a.addEventListener('click', e => { e.preventDefault(); h.scrollIntoView({ behavior: 'smooth', block: 'start' }); history.replaceState(null, '', '#' + h.id); });
      toc.appendChild(a);
    });
    const main = document.querySelector('.main'); if (main) main.appendChild(toc);
    const links = toc.querySelectorAll('.toc-link');
    let ticking = false;
    function updateActive() {
      let active = null;
      headings.forEach(h => { if (h.getBoundingClientRect().top <= 80) active = h; });
      links.forEach(a => a.classList.toggle('active', active && a.getAttribute('href') === '#' + active.id));
      ticking = false;
    }
    window.addEventListener('scroll', () => { if (!ticking) { requestAnimationFrame(updateActive); ticking = true; } }, { passive: true });
    updateActive();
  }

  /* ── Keyboard ── */
  document.addEventListener('keydown', e => {
    if ((e.metaKey || e.ctrlKey) && e.key === 'k') { e.preventDefault(); openSearch(); }
    if (e.key === 'Escape') closeSearch();
  });

  /* ── Init ── */
  document.addEventListener('DOMContentLoaded', () => {
    buildSidebar(); createSearchOverlay(); buildToc();
    buildIndex().then(idx => { searchIndex = idx; searchReady = true; });
  });

  window.chakraArch = { openSearch, REPO, PAGES_BASE };
})();
