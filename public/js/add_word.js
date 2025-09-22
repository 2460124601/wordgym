(function(){
  const dlg   = document.getElementById('modal');
  const form  = document.getElementById('form-add-word');
  const btnOk = document.getElementById('btn-submit-word');
  const btnX  = document.getElementById('btn-close-modal');

  if (!form) return;
  if (btnX) btnX.addEventListener('click', () => dlg?.close?.());

  form.addEventListener('submit', async (e) => {
    e.preventDefault();

    const fd  = new FormData(form);
    const pos = fd.getAll('pos');
    const catIds = [...document.querySelectorAll('#form-cats input[name="category_ids"]:checked')].map(i => i.value);

    const payload = {
      headword:       (fd.get('headword') || '').trim(),
      pos:            pos,
      definition_zh:  fd.get('definition_zh') || '',
      definition_en:  fd.get('definition_en') || '',
      example:        fd.get('example') || '',
      example2:       fd.get('example2') || '',
      cambridge_url:  fd.get('cambridge_url') || '',
      category_ids:   catIds
    };

    const res = await fetch('/api/words', {
      method: 'POST',
      headers: { 'Content-Type':'application/json' },
      body: JSON.stringify(payload)
    });

    if (!res.ok) {
      alert('新增失敗：' + (await res.text()));
      return;
    }

    dlg?.close?.();
    location.reload();
  });
})();