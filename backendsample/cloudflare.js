const ALTER_IMG = `https://img.icons8.com/clouds/100/fire-element.png`;

export default {
    async fetch(request, env, ctx) {
        const auth = request.headers.get('Authorization');
        const url = new URL(request.url);

        // --- 公开页面 (无需 Auth) ---
        if (request.method === "GET") {
            if (url.pathname === "/favicon.ico") {
                const cfico = `https://img.icons8.com/external-tal-revivo-filled-tal-revivo/96/external-cloudflare-provides-content-delivery-network-services-ddos-mitigation-logo-filled-tal-revivo.png`;
                return Response.redirect(cfico, 302);
            }
            const html = `<!DOCTYPE html><html><head><title>Cloudflare Workers</title><meta charset="utf-8"></head><body><h1>Service Active</h1></body></html>`;
            return new Response(html, { headers: { "Content-Type": "text/html;charset=UTF-8" } });
        }

        // --- 权限校验 (针对所有需要 Auth 的请求) ---
        if (!auth) {
            return new Response("Missing Authorization", { status: 401 });
        }

        // --- POST 请求处理 ---
        if (request.method === "POST") {
            const body = await request.json();

            // ---------- 1. 注册接口 ----------
            if (body.action === "register") {
                // 注册必然需要 Turnstile Token 来防滥用
                const { turnstileToken } = body;
                if (!turnstileToken) {
                    return new Response("Turnstile token required", { status: 400 });
                }
                const ip = request.headers.get('CF-Connecting-IP');
                const isHuman = await verifyTurnstile(turnstileToken, env.TURNSTILE_SECRET_KEY, ip);
                if (!isHuman) {
                    return new Response("Turnstile verification failed", { status: 403 });
                }

                // 检查用户是否已存在
                const existing = await env.DB.prepare('SELECT authorization FROM users WHERE authorization = ?').bind(auth).first();
                if (existing) {
                    return new Response("User already exists", { status: 409 });
                }

                // 创建新用户
                await env.DB.prepare('INSERT INTO users (authorization, tokens, devices) VALUES (?, ?, ?)')
                    .bind(auth, '', '').run();
                return new Response(JSON.stringify({ success: true, authorization: auth }), {
                    status: 201,
                    headers: { "Content-Type": "application/json" }
                });
            }

            // ---------- 2. 登录/校验接口 ----------
            if (body.action === "login") {
                const user = await env.DB.prepare('SELECT authorization FROM users WHERE authorization = ?').bind(auth).first();
                if (user) {
                    return new Response(JSON.stringify({ success: true }), { headers: { "Content-Type": "application/json" } });
                } else {
                    return new Response(JSON.stringify({ success: false, message: "User not found" }), { headers: { "Content-Type": "application/json" } });
                }
            }

            // ---------- 3. 发送消息 (保留原逻辑) ----------
            if (body.action === "message") {
                const { data, overview = "Null Overview", service = "Null Service", image = null, turnstileToken } = body;

                // 如果你希望在发消息时也做二次验证，可以取消下面的注释
                // if (turnstileToken) {
                //     const ip = request.headers.get('CF-Connecting-IP');
                //     const isHuman = await verifyTurnstile(turnstileToken, env.TURNSTILE_SECRET_KEY, ip);
                //     if (!isHuman) {
                //         return new Response("Turnstile verification failed", { status: 403 });
                //     }
                // }

                // 1. 写入 D1
                await env.DB.prepare(
                    'INSERT INTO main (timestamp, data, service, overview, image, authorization) VALUES (?, ?, ?, ?, ?, ?)'
                ).bind(
                    Date.now(),
                    typeof data === 'object' ? JSON.stringify(data) : data || null,
                    service,
                    overview,
                    image,
                    auth
                ).run();

                // 2. FCM 推送逻辑
                const saJson = await env.KV.get('service-account');
                if (saJson) {
                    const serviceAccount = JSON.parse(saJson);
                    const userRow = await env.DB.prepare('SELECT tokens, devices FROM users WHERE authorization = ?').bind(auth).first();

                    if (userRow && userRow.tokens) {
                        const tokenList = userRow.tokens.split(';').filter(t => t);
                        const tasks = tokenList.map(async (token) => {
                            return await FCMSender(serviceAccount, token, overview, service, image || ALTER_IMG);
                        });
                        const results = await Promise.allSettled(tasks);
                        
                        // 自动清理失效 token
                        const invalidTokens = [];
                        tokenList.forEach((token, index) => {
                            if (results[index].status === 'fulfilled' && results[index].value === false) {
                                invalidTokens.push(token);
                            }
                        });
                        if (invalidTokens.length > 0) {
                            const validTokens = tokenList.filter(t => !invalidTokens.includes(t));
                            await env.DB.prepare('UPDATE users SET tokens = ? WHERE authorization = ?')
                                .bind(validTokens.join(';'), auth).run();
                        }
                    }
                }
                return new Response("success");
            }

            // ---------- 4. 查询日志 (保留原逻辑) ----------
            if (body.action === "get") {
                const quantity = body.quantity || 5;
                const service = body.service || null;

                let query, params;
                if (service) {
                    query = 'SELECT * FROM main WHERE authorization = ? AND service = ? ORDER BY timestamp DESC LIMIT ?';
                    params = [auth, service, quantity];
                } else {
                    query = 'SELECT * FROM main WHERE authorization = ? ORDER BY timestamp DESC LIMIT ?';
                    params = [auth, quantity];
                }

                const logs = await env.DB.prepare(query).bind(...params).all();
                return new Response(JSON.stringify(logs.results), { headers: { "Content-Type": "application/json" } });
            }
        }

        // --- PUT 请求处理 (注册/更新 Token) ---
        if (request.method === "PUT") {
            const body = await request.json();
            const { token, device } = body;

            if (!token || !device) return new Response("Invalid Payload", { status: 400 });
            if (device.includes(';')) return new Response("Device name cannot contain ';'", { status: 400 });

            const user = await env.DB.prepare('SELECT tokens, devices FROM users WHERE authorization = ?').bind(auth).first();

            if (user) {
                let tokens = user.tokens ? user.tokens.split(';') : [];
                let devices = user.devices ? user.devices.split(';') : [];

                if (!tokens.includes(token)) {
                    tokens.push(token);
                    devices.push(device);
                    await env.DB.prepare('UPDATE users SET tokens = ?, devices = ? WHERE authorization = ?')
                        .bind(tokens.join(';'), devices.join(';'), auth)
                        .run();
                }
                return new Response("updated");
            } else {
                // 如果用户不存在则自动注册（客户端首次连接）
                await env.DB.prepare('INSERT INTO users (authorization, tokens, devices) VALUES (?, ?, ?)')
                    .bind(auth, token, device).run();
                return new Response("registered", { status: 201 });
            }
        }

        return new Response("Invalid Method", { status: 405 });
    }
};

// ---------- Turnstile 验证函数 ----------
async function verifyTurnstile(token, secret, ip) {
    try {
        const formData = new FormData();
        formData.append('secret', secret);
        formData.append('response', token);
        if (ip) formData.append('remoteip', ip);
        const result = await fetch('https://challenges.cloudflare.com/turnstile/v0/siteverify', {
            method: 'POST',
            body: formData,
        });
        const outcome = await result.json();
        return outcome.success; // true 或 false
    } catch (e) {
        console.error('Turnstile verification error:', e);
        return false;
    }
}

// ---------- FCM 发送函数 ----------
async function FCMSender(sa, token, overview, service, image) {
    try {
        const accessToken = await getAccessToken(sa);
        const url = `https://fcm.googleapis.com/v1/projects/${sa.project_id}/messages:send`;

        const fcmBody = {
            message: {
                token: token,
                notification: { title: service, body: overview, image: image },
            }
        };

        const res = await fetch(url, {
            method: 'POST',
            headers: {
                'Authorization': `Bearer ${accessToken}`,
                'Content-Type': 'application/json'
            },
            body: JSON.stringify(fcmBody)
        });

        const result = await res.json();

        if (res.ok) {
            return true;
        } else {
            if (res.status === 404 || (result.error && result.error.status === 'UNREGISTERED')) {
                return false; // 标记为失效
            }
            console.error(`FCM API Error [${res.status}]:`, result.error?.message);
            return true;
        }
    } catch (err) {
        console.error("Network or Auth Error:", err);
        return true;
    }
}

/**
 * 生成 Google OAuth2 Access Token (RS256)
 */
async function getAccessToken(sa) {
    const now = Math.floor(Date.now() / 1000);

    const header = { alg: 'RS256', typ: 'JWT' };
    const payload = {
        iss: sa.client_email,
        scope: 'https://www.googleapis.com/auth/firebase.messaging',
        aud: 'https://oauth2.googleapis.com/token',
        exp: now + 3600,
        iat: now
    };

    const base64UrlEncode = (str) => btoa(str).replace(/\+/g, '-').replace(/\//g, '_').replace(/=/g, '');
    const encodedHeader = base64UrlEncode(JSON.stringify(header));
    const encodedPayload = base64UrlEncode(JSON.stringify(payload));
    const unsignedToken = `${encodedHeader}.${encodedPayload}`;

    // 处理私钥
    const pemContents = sa.private_key.replace(/-----BEGIN PRIVATE KEY-----|-----END PRIVATE KEY-----|\n/g, "");
    const binaryDer = Uint8Array.from(atob(pemContents), c => c.charCodeAt(0));

    const importedKey = await crypto.subtle.importKey(
        'pkcs8',
        binaryDer.buffer,
        { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' },
        false,
        ['sign']
    );

    const signature = await crypto.subtle.sign(
        'RSASSA-PKCS1-v1_5',
        importedKey,
        new TextEncoder().encode(unsignedToken)
    );

    const encodedSignature = btoa(String.fromCharCode(...new Uint8Array(signature)))
        .replace(/\+/g, '-').replace(/\//g, '_').replace(/=/g, '');

    const jwt = `${unsignedToken}.${encodedSignature}`;

    const response = await fetch('https://oauth2.googleapis.com/token', {
        method: 'POST',
        headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
        body: `grant_type=urn:ietf:params:oauth:grant-type:jwt-bearer&assertion=${jwt}`
    });

    const tokenData = await response.json();
    return tokenData.access_token;
}