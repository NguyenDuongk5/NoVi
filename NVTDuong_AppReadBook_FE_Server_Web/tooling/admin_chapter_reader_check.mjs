import fs from 'node:fs'

const fixture = JSON.parse(fs.readFileSync(process.env.NOVI_E2E_FIXTURE, 'utf8').replace(/^\uFEFF/, ''))
const port = process.env.CDP_PORT || '9242'
const web = process.env.WEB_BASE_URL || 'http://localhost:4000'
const chapterIndex = Number(process.env.CHAPTER_INDEX || 0)
const expectedText = process.env.EXPECT_TEXT || 'Khoảng cách trên trang giấy'
const screenshotName = process.env.SCREENSHOT_NAME || 'admin-chapter-reader.png'
fs.mkdirSync('screenshots', { recursive: true })

const target = await fetch(`http://127.0.0.1:${port}/json/new?${encodeURIComponent(`${web}/login`)}`, { method: 'PUT' }).then(r => r.json())
const socket = new WebSocket(target.webSocketDebuggerUrl)
await new Promise((resolve, reject) => { socket.onopen = resolve; socket.onerror = reject })
let nextId = 0
const pending = new Map()
socket.onmessage = event => {
  const message = JSON.parse(event.data)
  if (message.id && pending.has(message.id)) { pending.get(message.id)(message); pending.delete(message.id) }
}
const send = (method, params = {}) => new Promise((resolve, reject) => {
  const id = ++nextId
  pending.set(id, message => message.error ? reject(new Error(JSON.stringify(message.error))) : resolve(message.result))
  socket.send(JSON.stringify({ id, method, params }))
})
const evaluate = async expression => (await send('Runtime.evaluate', { expression, awaitPromise: true, returnByValue: true })).result.value
const wait = async (expression, label, timeout = 15000) => {
  const until = Date.now() + timeout
  while (Date.now() < until) { if (await evaluate(expression)) return; await new Promise(resolve => setTimeout(resolve, 100)) }
  throw new Error(`Timeout: ${label}`)
}
const setValue = (selector, value) => `(()=>{const element=document.querySelector(${JSON.stringify(selector)});element.value=${JSON.stringify(value)};element.dispatchEvent(new Event('input',{bubbles:true}));return true})()`

try {
  await send('Page.enable')
  await send('Emulation.setDeviceMetricsOverride', { width: 1440, height: 900, deviceScaleFactor: 1, mobile: false })
  await wait(`document.readyState==='complete'`, 'load login')
  await evaluate(setValue('input[type=email]', fixture.accounts.admin))
  await evaluate(setValue('input[type=password]', fixture.password))
  await evaluate(`document.querySelector('form').requestSubmit();true`)
  await wait(`document.querySelector('.admin-shell')`, 'admin shell')
  if (process.env.THEME === 'dark') {
    await evaluate(`(()=>{const button=document.querySelector('button[aria-label="Chuyển sang giao diện tối"]');if(button)button.click();return true})()`)
    await wait(`document.documentElement.dataset.theme==='dark'`, 'dark theme')
  }
  await evaluate(`location.assign('/novels');true`)
  await wait(`document.querySelector('.filters input')`, 'novels page')
  await evaluate(setValue('.filters input', 'Bên Nhau Trọn Đời'))
  await evaluate(`document.querySelector('.filters').requestSubmit();true`)
  await wait(`document.querySelector('tr[data-novel-id="91000000-0000-0000-0000-000000000001"]')`, 'target novel')
  await evaluate(`document.querySelector('tr[data-novel-id="91000000-0000-0000-0000-000000000001"] .row-menu>.icon-button').click();true`)
  await wait(`document.querySelector('tr[data-novel-id="91000000-0000-0000-0000-000000000001"] .row-dropdown button')`, 'row menu')
  await evaluate(`document.querySelector('tr[data-novel-id="91000000-0000-0000-0000-000000000001"] .row-dropdown button').click();true`)
  await wait(`document.querySelector('.chapter-admin-row')`, 'chapter list')
  const initialScroll = await evaluate(`(()=>{const modal=document.querySelector('.novel-modal');modal.scrollTop=120;return modal.scrollTop})()`)
  await evaluate(`Array.from(document.querySelectorAll('.chapter-admin-row'))[${chapterIndex}].querySelector('.chapter-actions .button').click();true`)
  await wait(`document.querySelector('.chapter-content')`, 'chapter content')
  const reader = await evaluate(`({title:document.querySelector('.chapter-reader h3')?.textContent,content:document.querySelector('.chapter-content')?.textContent,statuses:Array.from(document.querySelectorAll('.chapter-reader .status')).map(x=>x.textContent),hasBack:Array.from(document.querySelectorAll('.novel-modal button')).some(x=>x.textContent.includes('Quay lại danh sách chương'))})`)
  const readerVisibleText = await evaluate(`document.querySelector('.novel-modal').innerText`)
  const image = await send('Page.captureScreenshot', { format: 'png', captureBeyondViewport: false })
  fs.writeFileSync(`screenshots/${screenshotName}`, Buffer.from(image.data, 'base64'))
  await evaluate(`Array.from(document.querySelectorAll('.novel-modal button')).find(x=>x.textContent.includes('Quay lại danh sách chương')).click();true`)
  await wait(`document.querySelector('.chapter-admin-list')`, 'back to chapter list')
  const restoredScroll = await evaluate(`document.querySelector('.novel-modal').scrollTop`)
  const visibleText = `${reader.title || ''} ${reader.statuses.join(' ')} ${reader.content || ''} ${readerVisibleText}`
  const pass = visibleText.includes(expectedText) && reader.content?.length > 20 && reader.hasBack && restoredScroll === initialScroll
  console.log(JSON.stringify({ result: pass ? 'PASS' : 'FAIL', contentLength: reader.content?.length || 0, expectedTextVisible: visibleText.includes(expectedText), backButton: reader.hasBack, scrollRestored: restoredScroll === initialScroll, screenshot: `screenshots/${screenshotName}` }))
  if (!pass) process.exitCode = 1
} finally { socket.close() }
