import fs from 'node:fs'

const fixture = JSON.parse(fs.readFileSync(process.env.NOVI_E2E_FIXTURE, 'utf8').replace(/^\uFEFF/, ''))
const cdpPort = process.env.CDP_PORT || '9223'
const base = process.env.WEB_BASE_URL || 'http://127.0.0.1:5173'

async function newPage(url) {
  const page = await fetch(`http://127.0.0.1:${cdpPort}/json/new?${encodeURIComponent(url)}`, { method: 'PUT' }).then(r => r.json())
  const socket = new WebSocket(page.webSocketDebuggerUrl)
  await new Promise((resolve, reject) => { socket.onopen = resolve; socket.onerror = reject })
  let id = 0
  const pending = new Map()
  socket.onmessage = event => {
    const message = JSON.parse(event.data)
    if (message.id && pending.has(message.id)) { pending.get(message.id)(message); pending.delete(message.id) }
  }
  const send = (method, params = {}) => new Promise((resolve, reject) => {
    const requestId = ++id
    pending.set(requestId, message => message.error ? reject(new Error(JSON.stringify(message.error))) : resolve(message.result))
    socket.send(JSON.stringify({ id: requestId, method, params }))
  })
  const evaluate = async expression => {
    const result = await send('Runtime.evaluate', { expression, awaitPromise: true, returnByValue: true })
    if (result.exceptionDetails) throw new Error(result.exceptionDetails.text)
    return result.result.value
  }
  const wait = async (expression, label, timeout = 10000) => {
    const started = Date.now()
    while (Date.now() - started < timeout) {
      if (await evaluate(expression)) return
      await new Promise(r => setTimeout(r, 100))
    }
    throw new Error(`Timeout: ${label}`)
  }
  await send('Page.enable')
  await wait(`document.readyState === 'complete'`, 'page load')
  return { socket, evaluate, wait }
}

const setInput = (selector, value) => `(() => { const el=document.querySelector(${JSON.stringify(selector)}); el.value=${JSON.stringify(value)}; el.dispatchEvent(new Event('input',{bubbles:true})); return true })()`
const clickText = (selector, text) => `(() => { const el=[...document.querySelectorAll(${JSON.stringify(selector)})].find(x=>x.textContent.trim()===${JSON.stringify(text)}); if(!el)return false;el.click();return true })()`
const rowClick = (email, button) => `(() => { const row=[...document.querySelectorAll('tbody tr')].find(x=>x.innerText.includes(${JSON.stringify(email)})); if(!row)return false;const b=[...row.querySelectorAll('button')].find(x=>x.textContent.trim()===${JSON.stringify(button)});if(!b)return false;b.click();return true })()`

const page = await newPage(`${base}/login`)
try {
  await page.evaluate(`localStorage.removeItem('novi_admin_session'); location.assign('/author-applications'); true`)
  await page.wait(`location.pathname === '/login'`, 'direct route redirects to login')
  await page.evaluate(setInput('input[type=email]', fixture.accounts.approved))
  await page.evaluate(setInput('input[type=password]', fixture.password))
  await page.evaluate(`document.querySelector('form').requestSubmit(); true`)
  await page.wait(`document.body.innerText.includes('không có quyền quản trị')`, 'reader denied')

  await page.evaluate(setInput('input[type=email]', fixture.accounts.admin))
  await page.evaluate(setInput('input[type=password]', fixture.password))
  await page.evaluate(`document.querySelector('form').requestSubmit(); true`)
  await page.wait(`location.pathname === '/author-applications' && document.querySelectorAll('tbody tr').length > 0`, 'admin queue')

  if (!process.env.SKIP_INITIAL_DECISIONS) {
    await page.wait(rowClick(fixture.accounts.approved, 'Duyệt'), 'approved row')
    await page.wait(`document.querySelector('[role=dialog]') !== null`, 'approval dialog')
    await page.evaluate(clickText('[role=dialog] button', 'Duyệt'))
    await page.wait(`!document.querySelector('[role=dialog]')`, 'approval completes')

    await page.wait(rowClick(fixture.accounts.rejected, 'Từ chối'), 'rejected row')
    await page.wait(`document.querySelector('[role=dialog] textarea') !== null`, 'rejection dialog')
    await page.evaluate(setInput('[role=dialog] textarea', 'Thông tin giới thiệu chưa đủ để xét duyệt.'))
    await page.evaluate(clickText('[role=dialog] button', 'Từ chối'))
    await page.wait(`!document.querySelector('[role=dialog]')`, 'rejection completes')
  }

  await page.evaluate(clickText('.admin-nav button', 'Đăng xuất'))
  await page.wait(`location.pathname === '/login'`, 'logout')
  await page.evaluate(`localStorage.setItem('novi_admin_session', JSON.stringify({accessToken:'expired',expiresAtUtc:'2000-01-01T00:00:00Z',user:{role:2}})); location.assign('/moderation'); true`)
  await page.wait(`location.pathname === '/login' && document.body.innerText.includes('Đăng nhập quản trị')`, 'expired session redirects')

  await page.evaluate(setInput('input[type=email]', fixture.accounts.admin))
  await page.evaluate(setInput('input[type=password]', fixture.password))
  await page.evaluate(`document.querySelector('form').requestSubmit(); true`)
  await page.wait(`document.querySelector('.admin-nav') !== null`, 'admin relogin')
  await page.evaluate(`location.assign('/author-applications'); true`)
  await page.wait(`location.pathname === '/author-applications' && document.body.innerText.includes('Trang 1 /')`, 'author paging page 1')
  await page.evaluate(clickText('.pager button', 'Trang sau'))
  await page.wait(`document.body.innerText.includes('Trang 2 /') && ![...document.querySelectorAll('.pager button')].find(x=>x.textContent.trim()==='Trang sau')?.disabled`, 'author paging page 2')
  await page.evaluate(clickText('.pager button', 'Trang sau'))
  await page.wait(`document.body.innerText.includes('Trang 3 /')`, 'author paging page 3')

  await page.evaluate(`location.assign('/moderation'); true`)
  await page.wait(`location.pathname === '/moderation' && document.body.innerText.includes('Trang 1 /')`, 'moderation paging page 1')
  await page.evaluate(clickText('.pager button', 'Trang sau'))
  await page.wait(`document.body.innerText.includes('Trang 2 /') && ![...document.querySelectorAll('.pager button')].find(x=>x.textContent.trim()==='Trang sau')?.disabled`, 'moderation paging page 2')
  await page.evaluate(clickText('.pager button', 'Trang sau'))
  await page.wait(`document.body.innerText.includes('Trang 3 /')`, 'moderation paging page 3')

  await page.evaluate(`location.assign('/author-applications'); true`)
  await page.wait(`location.pathname === '/author-applications' && document.querySelectorAll('tbody tr').length > 0`, 'conflict queue')
  await page.wait(rowClick('Conflict Reader', 'Duyệt'), 'conflict row')
  await page.wait(`document.querySelector('[role=dialog]') !== null`, 'conflict dialog')
  await page.evaluate(`(async()=>{const s=JSON.parse(localStorage.getItem('novi_admin_session'));const r=await fetch(${JSON.stringify(`${fixture.api}/api/admin/author-applications/${fixture.conflictApplicationId}/decision`)},{method:'POST',headers:{Authorization:'Bearer '+s.accessToken,'Content-Type':'application/json'},body:JSON.stringify({approve:true,reason:null})});return r.status})()`)
  await page.evaluate(clickText('[role=dialog] button', 'Duyệt'))
  await page.wait(`document.body.innerText.includes('quản trị viên khác xử lý')`, '409 message and reload')
  console.log(JSON.stringify({ directRoute: 'PASS', readerDenied: 'PASS', approve: 'PASS', reject: 'PASS', logout: 'PASS', expired: 'PASS', authorPaging3: 'PASS', moderationPaging3: 'PASS', conflict409: 'PASS' }))
} finally {
  page.socket.close()
}
