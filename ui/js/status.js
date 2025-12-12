// File: /ui/js/status.js
import { API_BASE_URL } from './api.js';

function setStatusState(el, text, state) {
  if (!el) return;
  el.textContent = text;
  el.classList.remove('status-ok', 'status-bad');
  if (state) el.classList.add(state);
}

export async function checkSystemStatus(el) {
  if (!el) return;
  setStatusState(el, '서버·DB 상태 확인 중...', null);
  try {
    const resp = await fetch(`${API_BASE_URL}/health`);
    let data = {};
    try {
      data = await resp.json();
    } catch (e) {
      // ignore json parse errors
    }
    const serverStatus = data.server_status ?? (resp.ok ? 'ok' : 'error');
    const dbStatus = data.db_status ?? data.db ?? (resp.ok ? 'unknown' : 'error');
    const serverOk = serverStatus === 'ok';
    const dbOk = dbStatus === 'ok';
    const allOk = resp.ok && serverOk && dbOk;
    setStatusState(
      el,
      allOk ? '서버·DB 연결: 정상' : `서버 ${serverOk ? '정상' : '오류'} / DB ${dbOk ? '정상' : '오류'}`,
      allOk ? 'status-ok' : 'status-bad'
    );
  } catch (e) {
    setStatusState(el, '서버·DB 연결: 실패', 'status-bad');
  }
}
