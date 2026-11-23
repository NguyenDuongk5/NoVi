import fs from 'node:fs'

const fixture = JSON.parse(fs.readFileSync(process.env.NOVI_E2E_FIXTURE, 'utf8').replace(/^\uFEFF/, ''))
const phase = process.env.E2E_PHASE || 'setup'
const base = process.env.WEB_BASE_URL || 'http://127.0.0.1:5174'
const cdpPort = process.env.CDP_PORT || '9224'
const api = fixture.ucApi

async function request(path, options = {}) {
  const response = await fetch(`${api}${path}`, options)
  let data = null
  try { data = await response.json() } catch {}
  return { status: response.status, data }
}
const login = (email, password) => request('/api/auth/login', {
  method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ email, password }),
})

async function newPage(url) {
  const target = await fetch(`http://127.0.0.1:${cdpPort}/json/new?${encodeURIComponent(url)}`, { method: 'PUT' }).then(r => r.json())
  const socket = new WebSocket(target.webSocketDebuggerUrl)
  await new Promise((resolve, reject) => { socket.onopen = resolve; socket.onerror = reject })
  let nextId = 0
  const pending = new Map(), events = []
  socket.onmessage = event => {
    const message = JSON.parse(event.data)
    if (message.method) events.push(message)
    if (message.id && pending.has(message.id)) { pending.get(message.id)(message); pending.delete(message.id) }
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
  const type = async (selector, value) => {
    await evaluate(`(() => {const el=document.querySelector(${JSON.stringify(selector)});if(!el)return false;el.focus();el.select();return true})()`)
    await send('Input.insertText', { text: value })
  }
  await send('Page.enable'); await send('Network.enable')
  await wait(`document.readyState === 'complete'`, 'page load')
  return { socket, send, evaluate, wait, type, events }
}

const setValue = (selector, value) => `(() => { const el=document.querySelector(${JSON.stringify(selector)}); if(!el)return false;el.value=${JSON.stringify(value)};el.dispatchEvent(new Event('input',{bubbles:true}));el.dispatchEvent(new Event('change',{bubbles:true}));return true })()`
const submit = selector => `(() => { const form=document.querySelector(${JSON.stringify(selector)});if(!form)return false;form.requestSubmit();return true })()`
const rowButton = (attribute, id, index) => `(() => {const row=document.querySelector('[${attribute}="${id}"]');if(!row)return false;const button=row.querySelectorAll('button')[${index}];if(!button)return false;button.click();return true})()`
const lastDialogButton = `(() => {const buttons=document.querySelectorAll('[role=dialog] button');if(!buttons.length)return false;buttons[buttons.length-1].click();return true})()`

const page = await newPage(`${base}/login`)
try {
  await page.evaluate(`localStorage.removeItem('novi_admin_session');location.assign('/login');true`)
  await page.wait(`document.querySelector('form')`, 'login form')
  await page.evaluate(setValue('input[type=email]', fixture.accounts.admin))
  await page.evaluate(setValue('input[type=password]', fixture.password))
  await page.evaluate(submit('form'))
  await page.wait(`document.querySelector('.admin-nav')`, 'admin login')

  if (phase === 'restore') {
    await page.evaluate(`location.assign('/users');true`)
    await page.wait(`location.pathname==='/users'&&document.querySelector('.filters')`, 'users page')
    await page.type('.filters input', fixture.uc07Email); await page.evaluate(submit('.filters'))
    await page.wait(`document.querySelector('[data-user-id="${fixture.uc07UserId}"]')`, 'locked target')
    await page.evaluate(rowButton('data-user-id', fixture.uc07UserId, 0)); await page.wait(`document.querySelector('[role=dialog]')`, 'unlock dialog')
    await page.evaluate(lastDialogButton); await page.wait(`!document.querySelector('[role=dialog]')`, 'unlock completes')
    await page.evaluate(`location.assign('/categories');true`); await page.wait(`location.pathname==='/categories'&&document.querySelector('.filters')`, 'categories page')
    await page.type('.filters input', 'Ngôn tình'); await page.evaluate(submit('.filters'))
    await page.wait(`document.querySelector('[data-category-id="${fixture.ucCategoryId}"]')`, 'hidden category')
    await page.evaluate(rowButton('data-category-id', fixture.ucCategoryId, 1)); await page.wait(`document.querySelector('[role=dialog]')`, 'show dialog')
    await page.evaluate(lastDialogButton); await page.wait(`!document.querySelector('[role=dialog]')`, 'show completes')
    const relogin = await login(fixture.uc07Email, fixture.password)
    const categories = await request('/api/categories')
    if (relogin.status !== 200 || !categories.data.some(x => x.categoryId === fixture.ucCategoryId)) throw new Error('Restore verification failed')
    console.log(JSON.stringify({ unlockFromChrome: 'PASS', newLoginAfterUnlock: 'PASS', showCategoryFromChrome: 'PASS', activeCategoryPublicAgain: 'PASS' }))
    process.exitCode = 0
  } else {
    const readerLogin = await login(fixture.uc07Email, fixture.password)
    if (readerLogin.status !== 200) throw new Error('Reader fixture login failed')
    const readerToken = readerLogin.data.accessToken
    const forbidden = await request('/api/admin/users?page=1&pageSize=10', { headers: { Authorization: `Bearer ${readerToken}` } })
    if (forbidden.status !== 403) throw new Error(`Reader admin API expected 403, got ${forbidden.status}`)

    await page.evaluate(`location.assign('/users');true`)
    await page.wait(`location.pathname==='/users'&&document.querySelectorAll('tbody tr').length>0`, 'users page')
    await page.evaluate(`document.querySelectorAll('.pager button')[1].click();true`); await page.wait(`document.querySelector('.pager span').innerText.includes('2 /')&&!document.querySelectorAll('.pager button')[1].disabled`, 'users page 2')
    await page.evaluate(`document.querySelectorAll('.pager button')[1].click();true`); await page.wait(`document.querySelector('.pager span').innerText.includes('3 /')`, 'users page 3')

    await page.type('.filters input', '__khong_co_user__'); await page.evaluate(submit('.filters'))
    await page.wait(`document.querySelector('.empty')&&document.querySelector('.empty').innerText.includes('Không tìm thấy')`, 'users empty')
    await page.type('.filters input', fixture.uc07Email)
    await page.evaluate(`(() => {const selects=document.querySelectorAll('.filters select');selects[0].value='0';selects[0].dispatchEvent(new Event('change',{bubbles:true}));selects[1].value='1';selects[1].dispatchEvent(new Event('change',{bubbles:true}));return true})()`)
    await page.evaluate(submit('.filters'))
    await page.wait(`document.querySelector('[data-user-id="${fixture.uc07UserId}"]')`, 'user filters and search')

    await page.send('Network.emulateNetworkConditions', { offline:true, latency:0, downloadThroughput:0, uploadThroughput:0 })
    await page.evaluate(`document.querySelector('.page-header .button').click();true`)
    await page.wait(`document.querySelector('.notice.error')&&document.querySelector('.notice.error .link-button')`, 'users load error')
    await page.send('Network.emulateNetworkConditions', { offline:false, latency:0, downloadThroughput:-1, uploadThroughput:-1 })
    await page.evaluate(`document.querySelector('.notice.error .link-button').click();true`)
    await page.wait(`document.querySelector('[data-user-id="${fixture.uc07UserId}"]')&&!document.querySelector('.notice.error')`, 'users retry')

    await page.evaluate(rowButton('data-user-id', fixture.uc07UserId, 0)); await page.wait(`document.querySelector('[role=dialog]')`, 'lock dialog cancel')
    await page.evaluate(`document.querySelector('[role=dialog] button').click();true`); await page.wait(`!document.querySelector('[role=dialog]')`, 'lock cancelled')
    await page.evaluate(rowButton('data-user-id', fixture.uc07UserId, 0)); await page.wait(`document.querySelector('[role=dialog]')`, 'lock dialog')
    const marker = page.events.length
    await page.evaluate(`(() => {const b=document.querySelector('[role=dialog] button.danger');b.click();b.click();return true})()`)
    await page.wait(`!document.querySelector('[role=dialog]')`, 'lock completes')
    const lockUrl = `/api/admin/users/${fixture.uc07UserId}/status`
    const lockRequests = page.events.slice(marker).filter(e => e.method==='Network.requestWillBeSent'&&e.params.request.method==='PATCH'&&e.params.request.url.includes(lockUrl))
    if (lockRequests.length !== 1) throw new Error(`Expected one lock PATCH, got ${lockRequests.length}`)
    const oldToken = await request('/api/users/me', { headers: { Authorization: `Bearer ${readerToken}` } })
    const lockedLogin = await login(fixture.uc07Email, fixture.password)
    if (oldToken.status !== 403 || lockedLogin.status !== 403) throw new Error(`Lock enforcement failed old=${oldToken.status} login=${lockedLogin.status}`)

    await page.evaluate(`location.assign('/categories');true`); await page.wait(`location.pathname==='/categories'&&document.querySelectorAll('tbody tr').length>0`, 'categories page')
    await page.evaluate(`document.querySelectorAll('.pager button')[1].click();true`); await page.wait(`document.querySelector('.pager span').innerText.includes('2 /')&&!document.querySelectorAll('.pager button')[1].disabled`, 'categories page 2')
    await page.evaluate(`document.querySelectorAll('.pager button')[1].click();true`); await page.wait(`document.querySelector('.pager span').innerText.includes('3 /')`, 'categories page 3')
    await page.type('.filters input', '__khong_co_category__'); await page.evaluate(submit('.filters')); await page.wait(`document.querySelector('.empty')`, 'categories empty')

    await page.evaluate(`document.querySelector('.page-header .button.primary').click();true`); await page.wait(`document.querySelector('[role=dialog] input')`, 'create dialog')
    await page.evaluate(submit('[role=dialog] form')); await page.wait(`document.querySelector('[role=dialog] [role=alert]')`, 'empty category validation')
    await page.type('[role=dialog] input', 'Ngôn tình'); await page.evaluate(submit('[role=dialog] form'))
    await page.wait(`document.querySelector('[role=dialog] [role=alert]')&&document.querySelector('[role=dialog] input').value==='Ngôn tình'`, 'duplicate category keeps input')
    await page.evaluate(`document.querySelector('[role=dialog] button[type=button]').click();true`); await page.wait(`!document.querySelector('[role=dialog]')`, 'close duplicate dialog')

    const uniqueName = `Chrome E2E ${Date.now()}`
    await page.evaluate(`document.querySelector('.page-header .button.primary').click();true`); await page.wait(`document.querySelector('[role=dialog] input')`, 'create unique dialog')
    await page.type('[role=dialog] input', uniqueName); await page.evaluate(submit('[role=dialog] form')); await page.wait(`!document.querySelector('[role=dialog]')`, 'category created')
    await page.type('.filters input', uniqueName); await page.evaluate(submit('.filters')); await page.wait(`document.querySelectorAll('tbody tr').length===1`, 'created category search')
    const createdId = await page.evaluate(`document.querySelector('tbody tr').dataset.categoryId`)
    await page.evaluate(rowButton('data-category-id', createdId, 0)); await page.wait(`document.querySelector('[role=dialog] input')`, 'edit category')
    await page.type('[role=dialog] input', `${uniqueName} đổi tên`); await page.evaluate(submit('[role=dialog] form')); await page.wait(`!document.querySelector('[role=dialog]')`, 'category renamed')

    await page.type('.filters input', 'Ngôn tình'); await page.evaluate(submit('.filters')); await page.wait(`document.querySelector('[data-category-id="${fixture.ucCategoryId}"]')`, 'linked category search')
    await page.evaluate(rowButton('data-category-id', fixture.ucCategoryId, 1)); await page.wait(`document.querySelector('[role=dialog]')`, 'hide category dialog')
    await page.evaluate(lastDialogButton); await page.wait(`!document.querySelector('[role=dialog]')`, 'hide category completes')
    const publicCategories = await request('/api/categories')
    const novel = await request(`/api/novels/${fixture.ucNovelId}`)
    if (publicCategories.data.some(x=>x.categoryId===fixture.ucCategoryId)) throw new Error('Hidden category remains public')
    if (!novel.data.categories.some(x=>x.categoryId===fixture.ucCategoryId)) throw new Error('Linked category missing from old novel detail')
    console.log(JSON.stringify({ readerAdmin403:'PASS',usersPaging3:'PASS',usersSearchFilterEmpty:'PASS',usersErrorRetry:'PASS',lockCancelConfirm:'PASS',lockRepeatedSinglePatch:'PASS',oldJwtAfterLock403:'PASS',newLoginLocked403:'PASS',categoriesPaging3:'PASS',categoriesEmpty:'PASS',categoryEmptyValidation:'PASS',categoryDuplicateKeepsInput:'PASS',categoryCreateRename:'PASS',categoryHideFromPublic:'PASS',oldNovelKeepsHiddenCategory:'PASS' }))
  }
} finally {
  try { await page.send('Network.emulateNetworkConditions', { offline:false, latency:0, downloadThroughput:-1, uploadThroughput:-1 }) } catch {}
  page.socket.close()
}
