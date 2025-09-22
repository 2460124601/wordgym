async function drawCaptcha() {
  const r = await fetch("/captcha/new", { credentials: "same-origin" });
  const { code } = await r.json();
  const c = document.getElementById("captcha-canvas");
  const ctx = c.getContext("2d");
  ctx.clearRect(0,0,c.width,c.height);
  ctx.fillStyle = "#f5f5f5"; ctx.fillRect(0,0,c.width,c.height);
  ctx.font = "bold 24px monospace";
  ctx.fillStyle = "#333";
  for (let i=0;i<3;i++){ ctx.strokeStyle="#ccc"; ctx.beginPath(); ctx.moveTo(Math.random()*c.width,0); ctx.lineTo(Math.random()*c.width,c.height); ctx.stroke(); }
  const x = 12, y = 26;
  for (let i=0;i<code.length;i++){
    const ch = code[i];
    ctx.save();
    ctx.translate(x + i*20, y);
    ctx.rotate((Math.random()-0.5)*0.35);
    ctx.fillText(ch,0,0);
    ctx.restore();
  }
}
document.getElementById("captcha-refresh").onclick = drawCaptcha;
drawCaptcha();