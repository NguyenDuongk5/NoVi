import fs from 'node:fs'

const fixture = JSON.parse(fs.readFileSync(process.env.NOVI_E2E_FIXTURE, 'utf8').replace(/^\uFEFF/, ''))
const cdpPort = process.env.CDP_PORT || '9223'
const base = process.env.WEB_BASE_URL || 'http://localhost:5173'

async function newPage(url) {
  const target = await fetch(`http://127.0.0.1:${cdpPort}/json/new?${encodeURIComponent(url)}`, { method: 'PUT' }).then(r => r.json())
  const socket = new WebSocket(target.webSocketDebuggerUrl)
  await new Promise((resolve, reject) => { socket.onopen = resolve; socket.onerror = reject })
  let nextId = 0
  const pending = new Map()
  const events = []
  socket.onmessage = event => {
    const message = JSON.parse(event.data)
    if (message.method) events.push(message)
    if (message.id && pending.has(message.id)) {
      pending.get(message.id)(message)
      pending.delete(message.id)
    }
  }
  const send = (method, params = {}) => new Promise((resolve, reject) => {
    const id = ++nextId
    pending.set(id, message => message.error ? reject(new Error(JSON.stringify(message.error))) : resolve(message.result))
    socket.send(JSON.stringify({ id, method, params }))
  })
  const evaluate = async expression => {
    const result = await send('Runtime.evaluate', { expression, awaitPromise: true, returnByValue: true })
    if (result.exceptionDetails) throw new Error(result.exceptionDetails.text)
    return result.result.value
  }
  const wait = async (expression, label, timeout = 15000) => {
    const started = Date.now()
    while (Date.now() - started < timeout) {
      if (await evaluate(expression)) return
      await new Promise(resolve => setTimeout(resolve, 100))
    }
    throw new Error(`Timeout: ${label}`)
  }
  await send('Page.enable')
  await send('Network.enable')
  await wait(`document.readyState === 'complete'`, 'page load')
  return { socket, send, evaluate, wait, events }
}

const input = (selector, value) => `(() => { const el=document.querySelector(${JSON.stringify(selector)}); if(!el)return false; el.value=${JSON.stringify(value)}; el.dispatchEvent(new Event('input',{bubbles:true})); return true })()`
const rowButton = (id, index) => `(() => { const row=document.querySelector('[data-application-id="${id}"]'); if(!row)return false; const button=row.querySelectorAll('button')[${index}]; if(!button)return false; button.click(); return true })()`
const confirmDialog = `(() => { const buttons=document.querySelectorAll('[role=dialog] button'); const button=buttons[buttons.length-1]; if(!button)return false; button.click(); return true })()`

const page = await newPage(`${base}/login`)
try {
  await page.evaluate(`localStorage.removeItem('novi_admin_session'); location.assign('/login'); true`)
  await page.wait(`document.querySelector('form') && document.querySelector('input[type=email]')`, 'login form')
  await page.evaluate(input('input[type=email]', fixture.accounts.admin))
  await page.evaluate(input('input[type=password]', fixture.password))
  await page.evaluate(`document.querySelector('form').requestSubmit(); true`)
  await page.wait(`location.pathname === '/author-applications' && document.querySelector('[data-application-id="${fixture.networkApplicationId}"]')`, 'admin application queue')

  await page.evaluate(rowButton(fixture.networkApplicationId, 1))
  await page.wait(`document.querySelector('[role=dialog] textarea')`, 'rejection dialog')
  const retainedReason = 'Ly do van con sau loi ket noi'
  await page.evaluate(input('[role=dialog] textarea', retainedReason))
  await page.send('Network.emulateNetworkConditions', { offline: true, latency: 0, downloadThroughput: 0, uploadThroughput: 0 })
  await page.evaluate(confirmDialog)
  await page.wait(`document.querySelector('[role=dialog] [role=alert]') && !document.querySelector('[role=dialog] button.danger').disabled`, 'connection error displayed')
  const reasonAfterFailure = await page.evaluate(`document.querySelector('[role=dialog] textarea').value`)
  if (reasonAfterFailure !== retainedReason) throw new Error('Rejection reason was lost after connection failure')
  await page.send('Network.emulateNetworkConditions', { offline: false, latency: 0, downloadThroughput: -1, uploadThroughput: -1 })

  await page.evaluate(`document.querySelector('[role=dialog] button:first-of-type').click(); true`)
  await page.wait(`!document.querySelector('[role=dialog]')`, 'close failed decision dialog')
  await page.wait(`document.querySelector('[data-application-id="${fixture.doubleApplicationId}"]')`, 'double-submit fixture')
  await page.evaluate(rowButton(fixture.doubleApplicationId, 0))
  await page.wait(`document.querySelector('[role=dialog]')`, 'approval dialog')
  const marker = page.events.length
  await page.evaluate(`(() => { const button=document.querySelector('[role=dialog] button.primary'); button.click(); button.click(); return true })()`)
  await page.wait(`!document.querySelector('[role=dialog]')`, 'approval completes')
  const decisionUrl = `/api/admin/author-applications/${fixture.doubleApplicationId}/decision`
  const requests = page.events.slice(marker).filter(event =>
    event.method === 'Network.requestWillBeSent' &&
    event.params.request.method === 'POST' &&
    event.params.request.url.includes(decisionUrl)
  )
  if (requests.length !== 1) throw new Error(`Expected exactly one decision request, got ${requests.length}`)

  console.log(JSON.stringify({ networkFailureKeepsReason: 'PASS', repeatedClickSingleRequest: 'PASS', decisionRequestCount: requests.length }))
} finally {
  try { await page.send('Network.emulateNetworkConditions', { offline: false, latency: 0, downloadThroughput: -1, uploadThroughput: -1 }) } catch {}
  page.socket.close()
}
