/**
 * dsh-arknights-stronghold
 * 明日方舟「卫戍协议·规程」操作辅助插件
 *
 * 设计原则：
 *  - 只调用 adb 截图 + 模拟触摸，不碰游戏文件/内存
 *  - 重活交给随包带的 PowerShell / Python 脚本（已经实战验证过）
 *  - 任何一环失败都返回结构化错误，不抛异常拖垮会话
 */
import { execFile } from 'node:child_process'
import { existsSync, readFileSync } from 'node:fs'
import { dirname, join, resolve } from 'node:path'
import { fileURLToPath } from 'node:url'

import { defineTool } from '@deepseek-ai/dsh-tools'

const HERE = dirname(fileURLToPath(import.meta.url))
const ROOT = resolve(HERE, '..')
const SCRIPTS = join(ROOT, 'scripts')
const DATA = join(ROOT, 'data')

export const name = 'dsh-arknights-stronghold'
export const inject = []

/** 默认配置（可在 cordis.yml 里覆盖） */
const DEFAULTS = {
  // MuMu 自带 adb，换模拟器要改这里
  adbPath: 'D:\\MuMu模拟器\\MuMuPlayer\\nx_device\\12.0\\shell\\adb.exe',
  // 脚本用的 python（需装 opencv / rapidocr-onnxruntime）
  pythonPath: 'python',
  powershellPath: 'powershell',
  // adb 端口；0 = 让脚本自己去 MuMuManager 读
  port: 0,
  timeoutMs: 180000,
}

function normConfig(raw) {
  const c = { ...DEFAULTS }
  if (raw && typeof raw === 'object') {
    for (const k of Object.keys(DEFAULTS)) {
      if (raw[k] !== undefined && raw[k] !== null && raw[k] !== '') c[k] = raw[k]
    }
  }
  return c
}

/** 跑一个 PowerShell 脚本，返回 stdout */
function runPs(cfg, script, args = []) {
  const file = join(SCRIPTS, script)
  if (!existsSync(file)) return Promise.reject(new Error(`脚本不存在: ${file}`))
  const argv = ['-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', file, ...args]
  return new Promise((res, rej) => {
    execFile(cfg.powershellPath, argv, { timeout: cfg.timeoutMs, windowsHide: true, maxBuffer: 4 * 1024 * 1024 },
      (err, stdout, stderr) => {
        if (err) return rej(new Error((stderr || stdout || err.message || '').trim() || 'PowerShell 执行失败'))
        res(String(stdout || ''))
      })
  })
}

/** 跑一个 Python 脚本 */
function runPy(cfg, script, args = []) {
  const file = join(SCRIPTS, script)
  if (!existsSync(file)) return Promise.reject(new Error(`脚本不存在: ${file}`))
  return new Promise((res, rej) => {
    execFile(cfg.pythonPath, [file, ...args], { timeout: cfg.timeoutMs, windowsHide: true, maxBuffer: 4 * 1024 * 1024 },
      (err, stdout, stderr) => {
        if (err) return rej(new Error((stderr || stdout || err.message || '').trim() || 'Python 执行失败'))
        res(String(stdout || ''))
      })
  })
}

/** 从脚本输出里抠出 JSON= 那一行 */
function pickJson(text) {
  const line = String(text || '').split(/\r?\n/).find((x) => x.startsWith('JSON='))
  if (!line) return null
  try { return JSON.parse(line.slice(5)) } catch { return null }
}

const portArg = (cfg) => ['-Port', String(cfg.port || 0)]

export function apply(ctx, rawConfig) {
  const cfg = normConfig(rawConfig)

  // ── ① 回合开始检查：金币 / 商店卡 / 敌人 / 升级费用 ──
  ctx.tools.register(defineTool({
    name: 'arknights_roundstart',
    description: '明日方舟卫戍协议：回合开始四步检查。读出当前金币、商店卡牌（名字/攻击/阻挡/资料库职业）、下一波敌人、商店升级费用。每回合开始先跑这个。',
    parameters: {
      port: { type: 'number', description: '可选，adb 端口；不传用插件配置' },
    },
    async execute(args) {
      const c = { ...cfg }
      if (args && args.port) c.port = args.port
      try {
        const out = await runPs(c, 'roundstart.ps1', portArg(c))
        return { ok: true, text: out.trim() }
      } catch (e) {
        return { ok: false, error: String(e.message || e) }
      }
    },
  }))

  // ── ② 按网格放干员（含强制收商店 + 核对） ──
  ctx.tools.register(defineTool({
    name: 'arknights_place',
    description: '明日方舟卫戍协议：把整备区的某个干员按九格网格放到指定格。会自动收起商店、拖到格子中心、划朝向，最后点格子核对名字。只能放「地面/围墙」格，不可放置格会被拒绝。',
    parameters: {
      unit: { type: 'string', description: '干员名字，如 陨星 / 褐果 / 摆渡人' },
      tile: { type: 'string', description: '目标格编号，如 d6 / c5 / a7（见 data/grid-ACSP2.json）' },
      face: { type: 'string', enum: ['right', 'left', 'up', 'down', 'none'], description: '放置后的朝向，本图默认 right（朝红门）' },
      port: { type: 'number', description: '可选，adb 端口' },
    },
    async execute(args) {
      const unit = String(args?.unit || '').trim()
      const tile = String(args?.tile || '').trim()
      if (!unit || !tile) return { ok: false, error: '必须同时给 unit 和 tile' }
      const c = { ...cfg }
      if (args?.port) c.port = args.port
      const face = String(args?.face || 'right')
      try {
        const out = await runPs(c, 'placegrid.ps1', ['-Unit', unit, '-Tile', tile, '-Face', face, ...portArg(c)])
        const ok = /放置正确/.test(out)
        return { ok, text: out.trim(), placed: ok, unit, tile }
      } catch (e) {
        return { ok: false, error: String(e.message || e) }
      }
    },
  }))

  // ── ③ 准备就绪 + 等下一回合 ──
  ctx.tools.register(defineTool({
    name: 'arknights_ready',
    description: '明日方舟卫戍协议：点「准备就绪」，自动处理「确认准备吗」弹窗，然后等待进入下一回合并报告回合数/剩余可放置。',
    parameters: {
      wait: { type: 'number', description: '等待秒数，默认 60' },
      port: { type: 'number', description: '可选，adb 端口' },
    },
    async execute(args) {
      const c = { ...cfg }
      if (args?.port) c.port = args.port
      const wait = Number(args?.wait || 60)
      try {
        const out = await runPs(c, 'ready.ps1', ['-Wait', String(wait), ...portArg(c)])
        return { ok: true, text: out.trim() }
      } catch (e) {
        return { ok: false, error: String(e.message || e) }
      }
    },
  }))

  // ── ④ 查网格坐标 ──
  ctx.tools.register(defineTool({
    name: 'arknights_grid',
    description: '查 AC-SP-2 的九格网格坐标。不传 tile 返回全部格子（含类型、像素、千分制）；传 tile 只返回那一格。用来确认某格是地面还是围墙、坐标是多少。',
    parameters: {
      tile: { type: 'string', description: '可选，格编号如 c6；不传返回全部' },
    },
    async execute(args) {
      try {
        const file = join(DATA, 'grid-ACSP2.json')
        const g = JSON.parse(readFileSync(file, 'utf8'))
        const cells = g['千分制']?.格子 || {}
        const tile = String(args?.tile || '').trim()
        if (tile) {
          const c = cells[tile]
          if (!c) return { ok: false, error: `网格里没有 ${tile}` }
          return { ok: true, tile, px: c.px, permille: c.permille, type: c['类型'] }
        }
        const ground = []
        const wall = []
        for (const [k, v] of Object.entries(cells)) {
          if (v['类型'] === '地面') ground.push(k)
          else if (v['类型'] === '围墙') wall.push(k)
        }
        return {
          ok: true,
          ground, wall,
          note: '地面能阻挡敌人；围墙能放人但不阻挡，近战敌人打不到，但不免疫远程/AOE',
          all: cells,
        }
      } catch (e) {
        return { ok: false, error: String(e.message || e) }
      }
    },
  }))

  // ── ⑤ 查干员（职业/位置/词条） ──
  ctx.tools.register(defineTool({
    name: 'arknights_operator',
    description: '查卫戍协议干员资料：职业、位置（近战/远程）、等阶、攻击、阻挡、所属盟约、词条。放人前必须查这个定职业，不许用阻挡数猜。',
    parameters: {
      name: { type: 'string', description: '干员名字，支持模糊匹配' },
    },
    async execute(args) {
      try {
        const want = String(args?.name || '').trim()
        if (!want) return { ok: false, error: '需要给 name' }
        const db = JSON.parse(readFileSync(join(DATA, 'operators.json'), 'utf8'))
        const list = db['干员'] || db.operators || []
        const hit = list.filter((o) => {
          const n = o['名字'] || o.name || ''
          return n === want || n.includes(want) || want.includes(n)
        })
        if (!hit.length) return { ok: false, error: `资料库里没有「${want}」` }
        return {
          ok: true,
          count: hit.length,
          operators: hit.slice(0, 5).map((o) => ({
            name: o['名字'] || o.name,
            tier: o['等阶'],
            job: o['职业'],
            position: o['位置'],
            core: o['核心盟约'],
            extra: o['附加盟约'],
            normal: o['普通词条'],
          })),
        }
      } catch (e) {
        return { ok: false, error: String(e.message || e) }
      }
    },
  }))

  // ── ⑥ 读可放置格（游戏高亮） ──
  ctx.tools.register(defineTool({
    name: 'arknights_tiles',
    description: '读游戏自己画的可放置高亮格（黄绿色）。传一张截图路径返回所有格子中心坐标。按住干员时截图效果最好——这是最准的坐标来源。',
    parameters: {
      image: { type: 'string', description: '截图文件路径' },
    },
    async execute(args) {
      const img = String(args?.image || '').trim()
      if (!img) return { ok: false, error: '需要给 image 路径' }
      try {
        const out = await runPy(cfg, 'tiles.py', [img])
        return { ok: true, text: out.trim(), tiles: pickJson(out) }
      } catch (e) {
        return { ok: false, error: String(e.message || e) }
      }
    },
  }))

  // ── ⑦ 视图校准 ──
  ctx.tools.register(defineTool({
    name: 'arknights_viewcheck',
    description: '校准镜头：用棋盘模板匹配算出当前画面相对基准图的偏移。偏移大的话网格坐标不能直接用，需要重新标。',
    parameters: {
      port: { type: 'number', description: '可选，adb 端口' },
    },
    async execute(args) {
      const c = { ...cfg }
      if (args?.port) c.port = args.port
      try {
        const out = await runPs(c, 'viewcheck.ps1', portArg(c))
        return { ok: true, text: out.trim() }
      } catch (e) {
        return { ok: false, error: String(e.message || e) }
      }
    },
  }))

  // 挂上时打一行，方便确认插件活着
  try {
    console.log('[arknights-stronghold] 已加载，脚本目录: ' + SCRIPTS)
  } catch { /* 忽略 */ }
}
