document.addEventListener("DOMContentLoaded", () => {
  
  const qs  = (s, r=document) => r.querySelector(s);
  const qsa = (s, r=document) => [...r.querySelectorAll(s)];
  const urlWith = (mut) => { const u = new URL(location.href); mut(u); return u.toString(); };

  
  function initChipsSelected(wrap) {
    if (!wrap) return;
    const sel = new Set(new URLSearchParams(location.search).getAll("cat[]"));
    qsa("[data-id]", wrap).forEach(btn => {
      if (sel.has(String(btn.dataset.id))) btn.classList.add("is-active");
    });
  }

  
  function bindChips(wrap) {
    if (!wrap) return;
    wrap.addEventListener("click", async (e) => {
      const chip = e.target.closest("[data-id]");
      if (!chip) return;
      const id = String(chip.dataset.id || "");

      const hitX = e.target.closest(".wg-chip__x");
      if (hitX) {
        e.stopPropagation();
        const name = chip.dataset.name || chip.textContent.trim();
        if (!confirm(`刪除「${name}」？\n（也會從所有單字移除此標籤）`)) return;
        const res = await fetch(`/api/categories/${id}`, {
          method: "DELETE",
          credentials: "same-origin"
        });
        if (!res.ok) { alert("刪除失敗：" + (await res.text().catch(()=> ""))); return; }
        location.href = urlWith(u => {
          const kept = u.searchParams.getAll("cat[]").filter(v => v !== id);
          ["cat","cat[]","cats","categories","categories[]","category"].forEach(k => u.searchParams.delete(k));
          kept.forEach(v => u.searchParams.append("cat[]", v));
        });
        return;
      }

      location.href = urlWith(u => {
        const cur = new Set(u.searchParams.getAll("cat[]"));
        if (chip.classList.toggle("is-active")) cur.add(id); else cur.delete(id);
        ["cat","cat[]","cats","categories","categories[]","category"].forEach(k => u.searchParams.delete(k));
        cur.forEach(v => u.searchParams.append("cat[]", v));
      });
    });
  }

  
  function wireDialogClose(dlg, closeSelectors = []) {
    if (!dlg) return;
    closeSelectors.forEach(sel => qs(sel)?.addEventListener("click", () => dlg.close()));
    dlg.addEventListener("click", (e) => { if (e.target === dlg) dlg.close(); });
    dlg.addEventListener("cancel", (e) => { e.preventDefault(); dlg.close(); });
  }

  
  
function bindCategoryModal() {
  const dlg   = document.querySelector("#wg-cat-modal");
  const form  = document.querySelector("#wg-cat-form");
  const name  = document.querySelector("#wg-cat-name");

  const open  = () => { if (dlg?.showModal) dlg.showModal(); name?.focus(); };

  const submit = async (e) => {
    e.preventDefault();
    const v = (name?.value || "").trim();
    if (!v) { alert("請輸入標籤名稱"); name?.focus(); return; }
    const r = await fetch("/api/categories", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      credentials: "same-origin",
      body: JSON.stringify({ name: v })
    });
    if (!r.ok) { alert("新增失敗：" + (await r.text().catch(()=> ""))); return; }
    const data = await r.json();
    dlg?.close?.();
    location.href = (() => { const u = new URL(location.href); u.searchParams.append("cat[]", data.id); return u.toString(); })();
  };

  document.querySelector("#wg-btn-cat-add")?.addEventListener("click", open);
  form?.addEventListener("submit", submit);

  wireDialogClose(dlg, ["#wg-cat-cancel", "#wg-cat-close-x"]);
}


  
  function bindRandomToggle() {
    const $rand = qs("#f-random");
    if (!$rand) return;
    const hasRandom = new URLSearchParams(location.search).get("random") === "true";
    $rand.checked = hasRandom;
    $rand.addEventListener("change", () => {
      location.href = urlWith(u => {
        if ($rand.checked) u.searchParams.set("random", "true");
        else u.searchParams.delete("random");
      });
    });
  }

  
  function init() {
    const chipsWrap = qs("#wg-cat-chips") || qs("#cat-chips");
    initChipsSelected(chipsWrap);
    bindChips(chipsWrap);
    bindCategoryModal();
    bindRandomToggle();
  }

  init();
});
