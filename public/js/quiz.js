const quizState = {
  total: 0,
  correct: 0,
  wrong: 0,
  startedAt: null,
  timerId: null
};

function updateStatsUI() {
  const t = document.getElementById("q-stats-total");
  const c = document.getElementById("q-stats-correct");
  const w = document.getElementById("q-stats-wrong");
  if (t) t.textContent = String(quizState.total);
  if (c) c.textContent = String(quizState.correct);
  if (w) w.textContent = String(quizState.wrong);
}

function formatDuration(ms) {
  const sec = Math.floor(ms / 1000);
  const h = Math.floor(sec / 3600);
  const m = Math.floor((sec % 3600) / 60);
  const s = sec % 60;
  const mm = String(m).padStart(2, "0");
  const ss = String(s).padStart(2, "0");
  return h > 0 ? `${h}:${mm}:${ss}` : `${mm}:${ss}`;
}

function startQuizTimer() {
  if (quizState.timerId) return;
  if (!quizState.startedAt) quizState.startedAt = Date.now();
  quizState.timerId = setInterval(() => {
    const el = document.getElementById("q-timer");
    if (el) el.textContent = formatDuration(Date.now() - quizState.startedAt);
  }, 250);
}

function resetQuizStats() {
  quizState.total = 0;
  quizState.correct = 0;
  quizState.wrong = 0;
  quizState.startedAt = Date.now();
  updateStatsUI();
  const el = document.getElementById("q-timer");
  if (el) el.textContent = "00:00";
}

function playPronunciation(text) {
  const audio = document.getElementById("q-audio");
  audio.src = `/tts/google?text=${encodeURIComponent(text)}&tl=en`;
  audio.play().catch(()=>{});
}

async function fetchQuestion() {
  const res = await fetch("/api/quiz/question?only_unremembered=true");
  if (!res.ok) {
    const t = await res.text().catch(()=> "");
    alert(t || "沒有題目，請先新增單字或取消只抽未記住");
    return null;
  }
  return res.json();
}

function renderQuestion(q) {
  const wordEl   = document.getElementById("q-word");
  const optsEl   = document.getElementById("q-options");
  const resultEl = document.getElementById("q-result");
  const mark     = document.getElementById("mark-remembered");
  const speakBtn = document.getElementById("btn-speak");

  wordEl.textContent = q.headword;
  optsEl.innerHTML   = "";
  resultEl.style.display = "none";
  mark.checked = false;

  speakBtn.onclick = () => playPronunciation(q.headword);

  q.options.forEach((txt, idx) => {
    const btn = document.createElement("button");
    btn.textContent = txt;
    btn.style.padding = "10px";
    btn.style.borderRadius = "10px";
    btn.style.border = "0.5px solid #006c36ff";
    btn.style.background = "#ffffffff";
    btn.style.color = "#3F4A34";

    btn.onclick = () => {

      const correct = idx === q.answer_index;

      quizState.total += 1;
      if (correct) quizState.correct += 1;
      else quizState.wrong += 1;
      updateStatsUI();

      btn.style.borderColor = correct ? "#2e7d32" : "#c62828";
      btn.style.background  = correct ? "#b7e5bbff" : "#ffbebeff";
      if (correct) {
        resultEl.style.display = "block";
      } else {
        const rightBtn = Array.from(optsEl.children)[q.answer_index];
        rightBtn.style.borderColor = "#2e7d32";
        rightBtn.style.background = "#e8f5e9";
      }

      Array.from(optsEl.children).forEach(b => b.disabled = true);
      optsEl.dataset.wordId = q.id;
    };

    optsEl.appendChild(btn);
  });
}

async function nextQuestion() {
  const optsEl = document.getElementById("q-options");
  const mark   = document.getElementById("mark-remembered");
  const wordId = optsEl.dataset.wordId;

  if (wordId && mark.checked) {
    await fetch(`/api/words/${wordId}/remembered`, {
      method: "PATCH",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ remembered: true })
    });
  }

  const q = await fetchQuestion();
  if (q) renderQuestion(q);
}

document.addEventListener("DOMContentLoaded", async () => {
  document.getElementById("btn-next").addEventListener("click", nextQuestion);
  document.getElementById("btn-reset-quiz")?.addEventListener("click", resetQuizStats);

  updateStatsUI();
  startQuizTimer();

  const q = await fetchQuestion();
  if (q) renderQuestion(q);
});
