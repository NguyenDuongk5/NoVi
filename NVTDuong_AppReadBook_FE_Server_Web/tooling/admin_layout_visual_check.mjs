import fs from 'node:fs'

const fixture = JSON.parse(fs.readFileSync(process.env.NOVI_E2E_FIXTURE, 'utf8').replace(/^\uFEFF/, ''))
const base = process.env.WEB_BASE_URL || 'http://localhost:4000'
const port = process.env.CDP_PORT || '9230'
const out = process.env.SCREENSHOT_DIR || 'screenshots'
fs.mkdirSync(out, { recursive: true })

const target = await fetch(`http://127.0.0.1:${port}/json/new?${encodeURIComponent(`${base}/login`)}`, { method: 'PUT' }).then(r => r.json())
const ws = new WebSocket(target.webSocketDebuggerUrl)
await new Promise((resolve, reject) => { ws.onopen = resolve; ws.onerror = reject })
let requestId = 0
const pending = new Map()
ws.onmessage = event => { const message = JSON.parse(event.data); if (message.id && pending.has(message.id)) { pending.get(message.id)(message); pending.delete(message.id) } }
const send = (method, params = {}) => new Promise((resolve, reject) => { const id = ++requestId; pending.set(id, message => message.error ? reject(Error(JSON.stringify(message.error))) : resolve(message.result)); ws.send(JSON.stringify({ id, method, params })) })
const evaluate = async expression => (await send('Runtime.evaluate', { expression, awaitPromise: true, returnByValue: true })).result.value
const wait = async (expression, label) => { for (let count = 0; count < 150; count++) { if (await evaluate(expression)) return; await new Promise(resolve => setTimeout(resolve, 100)) } throw Error(`Timeout ${label}`) }
const setValue = (selector, value) => `(()=>{const e=document.querySelector(${JSON.stringify(selector)});e.value=${JSON.stringify(value)};e.dispatchEvent(new Event('input',{bubbles:true}));return true})()`
const snap = async name => { const image = await send('Page.captureScreenshot', { format: 'png', captureBeyondViewport: false }); fs.writeFileSync(`${out}/${name}.png`, Buffer.from(image.data, 'base64')) }

try {
  await send('Page.enable')
  await send('Emulation.setDeviceMetricsOverride', { width: 1440, height: 900, deviceScaleFactor: 1, mobile: false })
  await wait(`document.readyState==='complete'`, 'load')
  await evaluate(setValue('input[type=email]', fixture.accounts.admin))
  await evaluate(setValue('input[type=password]', fixture.password))
  await evaluate(`document.querySelector('form').requestSubmit();true`)
  await wait(`document.querySelector('.admin-shell')`, 'login')
  await evaluate(`localStorage.setItem('novi-admin-theme','light');localStorage.setItem('novi-admin-sidebar','expanded');location.assign('/users');true`)
  await wait(`location.pathname==='/users'&&document.querySelector('.data-table')&&!document.querySelector('.admin-shell.collapsed')`, 'users')
  await snap('admin-users-light')
  await evaluate(`document.querySelector('.topbar-actions>.icon-button').click();true`)
  await wait(`document.documentElement.dataset.theme==='dark'`, 'dark theme')
  await snap('admin-users-dark')
  await evaluate(`document.querySelector('.desktop-collapse').click();location.reload();true`)
  await wait(`document.querySelector('.admin-shell.collapsed')`, 'collapsed persisted')
  await send('Emulation.setDeviceMetricsOverride', { width: 390, height: 844, deviceScaleFactor: 1, mobile: true })
  await evaluate(`location.reload();true`)
  await wait(`document.querySelector('.mobile-menu')`, 'mobile')
  await evaluate(`document.querySelector('.mobile-menu').click();true`)
  await wait(`document.querySelector('.drawer-open')`, 'drawer')
  await new Promise(resolve => setTimeout(resolve, 350))
  const drawerWidth = await evaluate(`Math.round(document.querySelector('.admin-nav').getBoundingClientRect().width)`)
  await snap('admin-mobile-drawer-dark')
  await send('Emulation.setDeviceMetricsOverride', { width: 1440, height: 900, deviceScaleFactor: 1, mobile: false })
  await evaluate(`location.assign('/categories');true`)
  await wait(`location.pathname==='/categories'&&document.querySelector('.filters')`, 'categories')
  await evaluate(`document.querySelector('.page-header .button.primary').click();true`)
  await wait(`document.querySelector('.modal')`, 'category modal')
  await evaluate(`document.querySelector('.modal-actions .button').click();true`)
  await wait(`!document.querySelector('.modal')`, 'category modal close')
  await evaluate(`location.assign('/author-applications');true`)
  await wait(`location.pathname==='/author-applications'&&document.querySelector('.card')`, 'author applications')
  await evaluate(`document.querySelector('.account-button').click();true`)
  await wait(`document.querySelector('.account-menu')`, 'account menu')
  await evaluate(`document.querySelector('.account-button').click();true`)
  await evaluate(`location.assign('/moderation');true`)
  await wait(`location.pathname==='/moderation'&&document.querySelector('.card')`, 'moderation')
  await snap('admin-moderation-dark')
  console.log(JSON.stringify({ login: 'PASS', lightDark: 'PASS', themePersisted: await evaluate(`localStorage.getItem('novi-admin-theme')==='dark'`), collapsePersisted: await evaluate(`localStorage.getItem('novi-admin-sidebar')==='collapsed'`), mobileDrawer: drawerWidth >= 280 ? 'PASS' : `FAIL:${drawerWidth}px`, fourAdminRoutes: 'PASS', categoryModal: 'PASS', accountDropdown: 'PASS' }))
} finally {
  ws.close()
}
