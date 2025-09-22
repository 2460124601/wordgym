document.addEventListener("DOMContentLoaded", () => {
    //功能：工具方法（$ / $$ / 轉義 / 改寫 URL）
    const $ = (sel, el = document) => el.querySelector(sel);
    const $$ = (sel, el = document) => [...el.querySelectorAll(sel)];
    const esc = (s) => String(s ?? "").replace(/[&<>"']/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
    const urlWith = (mut) => { const u = new URL(location.href); mut(u); return u.toString(); };

    //功能：判斷是否已登入
    function isLoggedIn() {
        return document.body.dataset.loggedIn === "true";
    }

    //功能：為 <dialog> 綁定通用關閉（叉叉、背景、Esc）
    function wireDialogClose(dlg, closeSelectors = []) {
        if (!dlg) return;
        closeSelectors.forEach(sel => $(sel)?.addEventListener("click", () => dlg.close()));
        dlg.addEventListener("click", (e) => { if (e.target === dlg) dlg.close(); });
        dlg.addEventListener("cancel", (e) => { e.preventDefault(); dlg.close(); });
    }

    //功能：開啟新增單字 modal
    function openAddModal() {
        $("#modal")?.showModal?.();
    }

    //功能：關閉新增單字 modal 並重置
    function closeAddModal() {
        const dlg = $("#modal");
        const form = $("#form-add-word");
        dlg?.close?.();
        form?.reset?.();
    }

    //功能：綁定新增單字 modal 的開關
    function bindAddDialog() {
        $("#btn-open-modal")?.addEventListener("click", openAddModal);
        wireDialogClose($("#modal"), ["#btn-close-modal", "#btn-close-modal-x"]);
    }

    //功能：送出新增單字
    function bindSubmitNewWord() {
        const form = $("#form-add-word");
        if (!form) return;
        form.addEventListener("submit", async (e) => {
            e.preventDefault();
            const fd = new FormData(form);
            const payload = {
                headword: (fd.get("headword") || "").trim(),
                pos: fd.getAll("pos"),
                definition_zh: fd.get("definition_zh") || "",
                definition_en: fd.get("definition_en") || "",
                example: fd.get("example") || "",
                example2: fd.get("example2") || "",
                cambridge_url: fd.get("cambridge_url") || "",
                category_ids: $$('#form-cats input[name="category_ids"]:checked').map(i => i.value)
            };
            try {
                const res = await fetch("/api/words", {
                    method: "POST",
                    headers: { "Content-Type": "application/json" },
                    credentials: "same-origin",
                    body: JSON.stringify(payload)
                });
                if (!res.ok) {
                    const t = await res.text().catch(() => "");
                    alert("新增失敗" + (t ? `：${t}` : ""));
                    return;
                }
                closeAddModal();
                location.reload();
            } catch {
                alert("網路錯誤，請稍後再試");
            }
        });
    }

    //功能：RWD 篩選區收合
    function bindFiltersCollapse() {
        const filtersEl = document.querySelector(".filters");
        const toggle = $("#filters-toggle");
        const bp = window.matchMedia("(max-width: 768px)");
        const apply = () => {
            if (!filtersEl) return;
            if (bp.matches) {
                const pref = localStorage.getItem("filters_collapsed_mobile") ?? "1";
                filtersEl.setAttribute("data-collapsed", pref);
                toggle?.setAttribute("aria-expanded", pref === "0" ? "true" : "false");
            } else {
                filtersEl.removeAttribute("data-collapsed");
                toggle?.setAttribute("aria-expanded", "true");
            }
        };
        const flip = () => {
            if (!filtersEl || !bp.matches) return;
            const collapsed = filtersEl.getAttribute("data-collapsed") === "1" ? "0" : "1";
            filtersEl.setAttribute("data-collapsed", collapsed);
            toggle.setAttribute("aria-expanded", collapsed === "0" ? "true" : "false");
            localStorage.setItem("filters_collapsed_mobile", collapsed);
        };
        apply();
        bp.addEventListener("change", apply);
        toggle?.addEventListener("click", flip);
    }

    //功能：列表狀態
    const state = {
        after: null,
        limit: 50,
        filters: { remembered: "", initial: "", starts: "", pos: [] },
        random: false,
        loading: false,
        loaded: 0,
        total: 0,
    };

    //功能：同步 random 參數
    function syncRandomFromUrl() {
        const has = new URLSearchParams(location.search).get("random") === "true";
        const chk = $("#f-random");
        if (chk) chk.checked = has;
        state.random = has;
    }
    syncRandomFromUrl();

    //功能：組合列表查詢參數
    function buildParams() {
        const u = new URLSearchParams(location.search);
        u.set("limit", String(state.limit));
        if (state.filters.remembered !== "") u.set("remembered", state.filters.remembered); else u.delete("remembered");
        if (state.filters.initial !== "") u.set("initial", state.filters.initial); else u.delete("initial");
        const s = (state.filters.starts || "").trim();
        if (s) u.set("starts", s); else u.delete("starts");
        u.delete("pos");
        (state.filters.pos || []).forEach(p => u.append("pos", p));
        if (state.random) { u.set("random", "true"); u.delete("after"); }
        else { u.delete("random"); if (state.after) u.set("after", state.after); else u.delete("after"); }
        return u;
    }

    //功能：渲染列表卡片
    function renderCard(it) {
        const zh = it.zh || "";
        return `
    <div class="word-card" data-id="${esc(it.id)}">
      <div class="wordCardContext">
        <div class="word-card-main">
          <div style="display:flex;align-items:center;gap:12px;">
            <a href="/words/${esc(it.id)}" aria-haspopup="dialog" aria-controls="word-modal"><h2 class="word-headword">${esc(it.headword)}</h2></a>
            <div style="width:20%;">
              <button class="speak" data-text="${esc(it.headword)}" style="background:#0000;padding:0;" aria-label="播放單字音訊" title="播放單字音訊"><img src="/icons/sound.svg" alt="發音" style="width:20px;height:20px;"></button>
            </div>
          </div>
          <div class="word-zh">${esc(zh)}</div>
        </div>
        <div class="word-card-actions">
          <button class="toggle-remembered ${it.remembered ? "is-remembered" : ""}" data-remembered="${it.remembered}" type="button" aria-pressed="${it.remembered}">
            <img src="${it.remembered ? "/icons/dobby_sock_full.svg" : "/icons/dobby_sock.svg"}"
                 alt="" class="icon-sock ${it.remembered ? "" : "icon-muted"}" style="width:20px;height:20px;"
                 title="${it.remembered ? "已熟悉" : "不熟悉"}" aria-label="${it.remembered ? "已熟悉" : "不熟悉"}">
          </button>
          <button class="edit" title="編輯單字" aria-label="編輯單字"><img src="/icons/edit.svg" alt="edit" style="width:20px;height:20px;"></button>
          <button class="delete" title="刪除單字" aria-label="刪除單字"><img src="/icons/delete.svg" alt="刪除" style="width:20px;height:20px;"></button>
        </div>
      </div>
    </div>`;
    }

    //功能：載入列表
    async function loadWords({ reset = false } = {}) {
        if (!isLoggedIn()) return;
        if (state.loading) return;
        state.loading = true;

        const listEl = $("#word-list") || $(".word-list-flex");
        const loadedEl = $("#loaded-count");
        const totalEl = $("#total-count");

        if (reset) {
            state.after = null;
            state.loaded = 0;
            listEl && (listEl.innerHTML = "");
            loadedEl && (loadedEl.textContent = "0");
            totalEl && (totalEl.textContent = "0");
        }

        try {
            const qs = buildParams().toString();
            const res = await fetch(`/api/words/list?${qs}`, { headers: { "Accept": "application/json" } });
            if (!res.ok) throw new Error("HTTP " + res.status);
            const data = await res.json();

            if (listEl) {
                const frag = document.createDocumentFragment();
                data.items.forEach(it => {
                    const wrap = document.createElement("div");
                    wrap.innerHTML = renderCard(it);
                    frag.appendChild(wrap.firstElementChild);
                });
                listEl.appendChild(frag);
            }

            if (state.random) {
                state.loaded = data.items.length;
                state.after = null;
            } else {
                state.loaded += data.items.length;
                state.after = data.next_cursor || null;
            }
            state.total = data.total || 0;

            loadedEl && (loadedEl.textContent = String(state.loaded));
            totalEl && (totalEl.textContent = String(state.total));
        } catch (err) {
            console.error(err);
            alert("載入失敗，請稍後再試");
        } finally {
            state.loading = false;
        }
    }

    //function-播放發音
    function playSpeak(btn) {
        const text = btn.getAttribute("data-text");
        const tl = document.querySelector('meta[name="app-word-lang"]')?.content || "en";
        const url = `/tts/google?text=${encodeURIComponent(text)}&tl=${encodeURIComponent(tl)}&_=${Date.now()}`;
        const audio = new Audio(url);
        audio.play().catch(() => { });
    }

    //function-切換記憶狀態（列表）
    async function toggleRememberedFromList(id, btn) {
        try {
            const res = await fetch(`/api/words/${id}/toggle_remembered`, { method: "PATCH", credentials: "same-origin" });
            if (!res.ok) { alert("切換失敗：" + (await res.text())); return; }
            const curr = btn.dataset.remembered === "true";
            const next = !curr;
            btn.dataset.remembered = String(next);
            btn.classList.toggle("is-remembered", next);
            btn.setAttribute("aria-pressed", String(next));
            const img = btn.querySelector("img.icon-sock");
            if (img) { img.src = next ? "/icons/dobby_sock_full.svg" : "/icons/dobby_sock.svg"; img.classList.toggle("icon-muted", !next); }
        } catch {
            alert("網路錯誤，請稍後再試");
        }
    }

    //功能：刪除單字（列表）
    async function deleteWordFromList(id, card) {
        if (!confirm("確定刪除？")) return;
        try {
            const res = await fetch(`/api/words/${id}`, { method: "DELETE", headers: { "Accept": "application/json" }, credentials: "same-origin" });
            if (!res.ok) { alert("刪除失敗：" + (await res.text())); return; }
            card.remove();
            const loadedEl = $("#loaded-count");
            state.loaded = Math.max(0, state.loaded - 1);
            loadedEl && (loadedEl.textContent = String(state.loaded));
        } catch {
            alert("網路錯誤，請稍後再試");
        }
    }

    //功能：綁定列表點擊行為
    function bindListActions() {
        const list = $("#word-list") || $(".word-list-flex");
        list?.addEventListener("click", (e) => {
            const card = e.target.closest(".word-card");
            const id = card?.getAttribute("data-id");
            if (!id) return;

            if (e.target.closest(".speak")) { playSpeak(e.target.closest(".speak")); return; }
            if (e.target.closest(".toggle-remembered")) { toggleRememberedFromList(id, e.target.closest(".toggle-remembered")); return; }
            if (e.target.closest(".edit")) { openEditModal(id); return; }
            if (e.target.closest(".delete")) { deleteWordFromList(id, card); return; }
        });
    }

    //功能：攔截點頭字 → 詳情 modal
    async function interceptHeadwordClick(e) {
        const anchor = e.target.closest('.word-card a[href^="/words/"]');
        if (!anchor) return;
        if (!e.target.closest(".word-headword")) return;
        if (e.ctrlKey || e.metaKey || e.button === 1 || anchor.target === "_blank") return;
        if (e.target.closest(".toggle-remembered, .delete, .edit, .speak")) return;

        e.preventDefault();
        const href = anchor.getAttribute("href");
        const wordModal = $("#word-modal");
        const body = $("#word-modal-body");
        try {
            const res = await fetch(href.replace(/\/$/, "") + "/partial", { headers: { "Accept": "text/html" } });
            if (!res.ok) throw new Error("HTTP " + res.status);
            const html = await res.text();
            if (body && wordModal) {
                body.innerHTML = html;
                wordModal.showModal();
            } else {
                window.location.href = href;
            }
        } catch (err) {
            console.error(err);
            window.location.href = href;
        }
    }

    //功能：詳情 modal 內部點擊（更新標籤 / 切換記憶）
    async function onWordDetailBodyClick(e) {
        const wordModal = $("#word-modal");
        const body = $("#word-modal-body");
        if (!body) return;

        if (e.target && e.target.id === "btn-save-word-tags") {
            const card = body.querySelector(".word-card");
            const wordId = card?.getAttribute("data-id");
            if (!wordId) { alert("缺少單字 ID"); return; }
            const ids = [...body.querySelectorAll('#wm-cats input[name="category_ids"]:checked')].map(i => i.value);
            const res = await fetch(`/api/words/${wordId}`, {
                method: "PATCH",
                headers: { "Content-Type": "application/json" },
                body: JSON.stringify({ category_ids: ids })
            });
            if (!res.ok) {
                const msg = await res.text().catch(() => "");
                alert("更新失敗：" + msg);
                return;
            }
            wordModal?.close?.();
            location.reload();
            return;
        }

        const toggleBtn = e.target.closest(".toggle-remembered");
        if (toggleBtn) {
            e.stopPropagation();
            const card = body.querySelector(".word-card");
            const wordId = card?.getAttribute("data-id");
            if (!wordId) return;
            try {
                const res = await fetch(`/api/words/${wordId}/toggle_remembered`, { method: "PATCH", credentials: "same-origin" });
                if (!res.ok) { alert("切換失敗：" + (await res.text())); return; }
                const curr = toggleBtn.dataset.remembered === "true";
                const next = !curr;
                toggleBtn.dataset.remembered = String(next);
                toggleBtn.classList.toggle("is-remembered", next);
                toggleBtn.setAttribute("aria-pressed", String(next));
                const img = toggleBtn.querySelector("img.icon-sock");
                if (img) {
                    img.src = next ? "/icons/dobby_sock_full.svg" : "/icons/dobby_sock.svg";
                    img.classList.toggle("icon-muted", !next);
                    img.title = next ? "已熟悉" : "不熟悉";
                    img.setAttribute("aria-label", next ? "已熟悉" : "不熟悉");
                }
            } catch {
                alert("網路錯誤，請稍後再試");
            }
        }
    }

    //功能：綁定詳情 modal 的開關與事件
    function bindDetailDialog() {
        wireDialogClose($("#word-modal"), ["#word-modal-close"]);
        document.addEventListener("click", interceptHeadwordClick);
        $("#word-modal-body")?.addEventListener("click", onWordDetailBodyClick);
    }

    //功能：將資料填入編輯表單
    function fillEditForm(w) {
        const form = $("#form-edit-word");
        if (!form) return;
        form.dataset.id = w.id;
        $("#edit-id")?.setAttribute("value", w.id);
        $("#edit-headword") && ($("#edit-headword").value = w.headword || "");
        $("#edit-cambridge") && ($("#edit-cambridge").value = w.cambridge_url || "");
        $("#edit-zh") && ($("#edit-zh").value = w.definition_zh || "");
        $("#edit-en") && ($("#edit-en").value = w.definition_en || "");
        $("#edit-example") && ($("#edit-example").value = w.example || "");
        $("#edit-example2") && ($("#edit-example2").value = w.example2 || "");
        $("#edit-remembered") && ($("#edit-remembered").checked = !!w.remembered);

        const posWrap = $("#edit-pos");
        if (posWrap) {
            posWrap.innerHTML = "";
            const options = (window.POS_OPTIONS || w.pos_options || []);
            options.forEach((p, i) => {
                const id = `edit-pos-${p}`;
                const checked = Array.isArray(w.pos) && w.pos.includes(p);
                posWrap.insertAdjacentHTML("beforeend", `
          <input type="checkbox" id="${id}" name="pos" value="${p}" class="pillset__ctrl" ${checked ? "checked" : ""}>
          <label for="${id}" class="pill" data-c="${(i % 3) + 1}">${p}</label>
        `);
            });
        }

        const catsWrap = $("#edit-cats");
        if (catsWrap) {
            catsWrap.innerHTML = "";
            const allCats = w.all_categories || [];
            const selected = (w.category_ids || []).map(String);
            allCats.forEach((c, i) => {
                const id = `edit-cat-${c._id}`;
                const checked = selected.includes(String(c._id));
                catsWrap.insertAdjacentHTML("beforeend", `
          <input type="checkbox" id="${id}" name="category_ids" value="${c._id}" class="pillset__ctrl" ${checked ? "checked" : ""}>
          <label for="${id}" class="pill" data-c="${(i % 3) + 1}">${c.name}</label>
        `);
            });
        }
    }

    //功能：開啟編輯 modal 並載入
    async function openEditModal(wordId) {
        const dlg = $("#word-edit-modal");
        if (!dlg) { location.href = `/words/${wordId}/edit`; return; }
        try {
            const res = await fetch(`/api/words/${wordId}`, { headers: { "Accept": "application/json" }, credentials: "same-origin" });
            if (!res.ok) throw new Error("HTTP " + res.status);
            const w = await res.json();
            fillEditForm(w);
            dlg.showModal();
        } catch (err) {
            console.error(err);
            alert("載入失敗");
        }
    }

    //功能：收集編輯表單
    function collectEditPayload() {
        const fd = new FormData($("#form-edit-word"));
        return {
            headword: fd.get("headword"),
            pos: fd.getAll("pos"),
            definition_zh: fd.get("definition_zh"),
            definition_en: fd.get("definition_en"),
            example: fd.get("example"),
            example2: fd.get("example2"),
            cambridge_url: fd.get("cambridge_url"),
            remembered: fd.get("remembered") === "on",
            category_ids: fd.getAll("category_ids")
        };
    }

    //功能：送出編輯表單
    async function submitEditForm(e) {
        e.preventDefault();
        const form = $("#form-edit-word");
        const id = form?.dataset.id;
        if (!id) return;
        const payload = collectEditPayload();
        const res = await fetch(`/api/words/${id}`, {
            method: "PATCH",
            headers: { "Content-Type": "application/json" },
            credentials: "same-origin",
            body: JSON.stringify(payload)
        });
        if (!res.ok) {
            const t = await res.text().catch(() => "");
            alert(`更新失敗：${res.status} ${t}`);
            return;
        }
        $("#word-edit-modal")?.close?.();
        location.reload();
    }

    //功能：從編輯 modal 刪除
    async function deleteFromEditModal() {
        const form = $("#form-edit-word");
        const id = form?.dataset.id;
        if (!id) return;
        if (!confirm("確定要刪除這個單字？")) return;
        const res = await fetch(`/api/words/${id}`, { method: "DELETE", credentials: "same-origin" });
        if (!res.ok) {
            const t = await res.text().catch(() => "");
            alert(`刪除失敗：${res.status} ${t}`);
            return;
        }
        $("#word-edit-modal")?.close?.();
        location.reload();
    }

    //功能：綁定編輯 modal 的開關與提交
    function bindEditDialog() {
        wireDialogClose($("#word-edit-modal"), ["#btn-close-edit", "#btn-close-edit-x"]);
        $("#form-edit-word")?.addEventListener("submit", submitEditForm);
        $("#btn-delete-edit")?.addEventListener("click", deleteFromEditModal);
    }

    //功能：綁定篩選控件
    function bindFiltersControls() {
        $("#btn-quiz")?.addEventListener("click", () => { location.href = "/quiz"; });
        $("#f-remembered")?.addEventListener("change", () => { state.filters.remembered = $("#f-remembered").value; loadWords({ reset: true }); });
        $("#initial-chips")?.addEventListener("click", (e) => {
            const b = e.target.closest(".chip");
            if (!b) return;
            $("#initial-chips").querySelectorAll(".chip").forEach(x => x.classList.remove("is-active"));
            b.classList.add("is-active");
            state.filters.initial = b.dataset.v || "";
            loadWords({ reset: true });
        });
        let startsTimer;
        const onStartsInput = () => {
            clearTimeout(startsTimer);
            startsTimer = setTimeout(() => {
                state.filters.starts = $("#f-starts").value || "";
                loadWords({ reset: true });
            }, 250);
        };
        $("#f-starts")?.addEventListener("input", onStartsInput);
        $("#f-pos")?.addEventListener("change", () => {
            state.filters.pos = Array.from($("#f-pos").selectedOptions).map(o => o.value);
            loadWords({ reset: true });
        });
    }

    //功能：無限卷動
    function bindInfiniteScroll() {
        const sentinel = $("#scroll-sentinel");
        const canAutoLoad = () => !state.random && !state.loading && !!state.after;
        if (sentinel && "IntersectionObserver" in window) {
            const onIntersect = (entries) => {
                if (entries.some(e => e.isIntersecting) && canAutoLoad()) loadWords();
            };
            const io = new IntersectionObserver(onIntersect, { rootMargin: "200px 0px 200px 0px" });
            io.observe(sentinel);
        } else {
            const onScrollLoad = () => {
                if (!canAutoLoad()) return;
                const nearBottom = window.innerHeight + window.scrollY >= document.body.offsetHeight - 300;
                if (nearBottom) loadWords();
            };
            window.addEventListener("scroll", onScrollLoad, { passive: true });
        }
    }

    function init() {
        bindAddDialog();
        bindSubmitNewWord();
        bindFiltersCollapse();
        bindListActions();
        bindDetailDialog();
        bindEditDialog();
        bindFiltersControls();
        bindInfiniteScroll();
        loadWords({ reset: true });
        console.log("千金難買早知道，一開始就應該用 jQuery 的");
    }

    init();
});
