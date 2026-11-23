-- 素笺（Vellum）极简数据库初始化脚本（PostgreSQL）
-- 约定：仅 3 张核心表，严禁物理外键，表间全部采用逻辑关联

-- 1. 用户表（单人自用账号）
CREATE TABLE IF NOT EXISTS sys_user (
    id            VARCHAR(36)  PRIMARY KEY,
    username      VARCHAR(64)  NOT NULL UNIQUE,
    password_hash VARCHAR(128) NOT NULL,
    created_at    TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

-- 默认初始用户（username: Luojiakeng / password: 690501 的 BCrypt 密文）
INSERT INTO sys_user (id, username, password_hash)
VALUES ('00000000-0000-0000-0000-000000000001', 'Luojiakeng', '$2a$10$ORz7YyCV22s.6gp.Ld5/T.oJHGv3r.WHYAQc1kqfBojqtQdyURrWK')
ON CONFLICT (username) DO NOTHING;

-- 2. 动态 / 长文主表（所有正文统一存 PostgreSQL TEXT）
CREATE TABLE IF NOT EXISTS post (
    id            VARCHAR(36)  PRIMARY KEY,
    type          VARCHAR(16)  NOT NULL,
    title         VARCHAR(200),
    content       TEXT         NOT NULL,
    location_city VARCHAR(64),
    record_time   TIMESTAMPTZ  NOT NULL,
    deleted       BOOLEAN      NOT NULL DEFAULT FALSE,
    created_at    TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    updated_at    TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);
ALTER TABLE post ADD COLUMN IF NOT EXISTS deleted BOOLEAN NOT NULL DEFAULT FALSE;
CREATE INDEX IF NOT EXISTS idx_post_record_time ON post (record_time DESC);
CREATE INDEX IF NOT EXISTS idx_post_city ON post (location_city);

-- 模拟动态与长文数据（可重复执行）
INSERT INTO post (id, type, title, content, location_city, record_time)
VALUES
(
    '00000000-0000-0000-0000-000000000101',
    'MOMENT',
    NULL,
    '下班前十分钟，产品经理端着冰美式笑眯眯走过来：就改个小按钮的颜色和位置，五分钟的事。结果两小时后，我对着三个报错弹窗和已经凉透的黄焖鸡米饭，深刻理解了什么叫软件工程里的相对论——他嘴里的五分钟，相当于宇宙大爆炸一次。',
    '杭州市',
    '2026-11-20T18:35:00+08:00'
),
(
    '00000000-0000-0000-0000-000000000102',
    'MOMENT',
    NULL,
    '昨晚立下铁血 Flag 今早六点半去晨跑，连定了六个交响乐闹钟。结果今早在完全没睁眼的情况下，以职业电竞选手的盲操手速精准点掉了全部六个闹钟并完成二次翻身。十点半醒来为了不辜负运动计划，果断下单了一个双倍芝士厚牛堡，重点锻炼了一下咀嚼肌。',
    '上海市',
    '2026-11-21T22:10:00+08:00'
),
(
    '00000000-0000-0000-0000-000000000201',
    'ARTICLE',
    '暴雨夜的高架桥与未寄出的情书',
    '## 暴雨夜的高架桥与未寄出的情书

九月的暴雨砸在高架桥隔音板上，像无数个无处可去的旧梦同时叩门。尾灯在积水里晕成大片暗红，整个城市忽然变成一艘即将沉没的豪华邮轮，而我只是缩在后排座位里、连救生衣都懒得穿的衰仔。

> 孤独从来不是没人说话，而是你在人群中央突然明白，世上再没有一个人愿意为你对抗整个世界的风雪。

很多年前我也曾爱过一个女孩。她站在老街尽头的屋檐下躲雨，发梢滴着亮晶晶的水珠，转过头笑得像刚偷到全宇宙糖果的小狐狸。那时候我们都天真得可笑，以为只要把掌心攥紧，就能替彼此挡住往后余生所有的冷雨和夜风。可惜青春这趟单程列车从不报站，后来她走向亮着璀璨霓虹的彼岸，我留在零点的站台上，手里只剩一张早已作废的车票。

我始终记得我们各自退场前夜的荒唐：明明想说留下吧，出口却变成了路上小心；明明把全世界的温柔都攒在怀里，却只敢在微信对话框里打了又删，最后发过去一句冷冰冰的晚安。

爱情大概就像在暴风雪的荒野里划燃最后一根火柴，明知道那点微光最多撑过三秒钟，明知道烧尽之后是更彻骨的寒冷与漆黑，可蠢家伙们还是会毫不犹豫地划下去——因为人这辈子总要为了那三秒钟的滚烫，甘愿交出往后十年的孤独。',
    '北京市',
    '2026-11-19T23:40:00+08:00'
),
(
    '00000000-0000-0000-0000-000000000202',
    'ARTICLE',
    '小怪兽的孤独守恒定律',
    '## 小怪兽的孤独守恒定律

凌晨一点的二十四小时便利店，总是孤单得像漂在黑海中央的太空站。玻璃门外是永不疲倦的车流与冷雨，门内只有关东煮在白汽里咕嘟作响，和冷柜深处嗡嗡震动的孤独。

曾经我以为自己早就练成了披着铁灰色鳞甲的小怪兽，百毒不侵，刀枪不入，一个人搬家、一个人挂水、一个人把所有情绪嚼碎了咽进胃里，就能体面地活成一座孤岛。直到那天在路灯底下遇见她，她什么豪言壮语也没讲，只是把一罐还带着温度的乌龙茶贴在我冰凉的侧脸上，笑着说今天风好大呀。那一瞬间，我苦心修了七年的城墙轰隆一声塌得干干净净，原来怪兽也会因为一点微不足道的善意而缴械投降。

> 这世上哪有什么天生的铁石心肠，不过是没有遇到那个刚好能接住你全部脆弱的人。

人越长大就越胆小，开始习惯用“算了”和“都行”把真心裹得严严实实，生怕再多走半步就会输得一败涂地。可命运偏偏最喜欢看清醒的人发疯，爱情原本就是一场注定血本无归的豪赌，你押上全部的自尊与骄傲，只求换一个和她并肩看烟花的瞬间。

哪怕烟花散尽之后，世界照样会回到最初的安静与冰冷；哪怕我们最后还是只能各自走入人海，各自成为彼此记忆里永不褪色的旧电影——至少在那个下着小雨的夜晚，我们曾短暂地做过拯救对方的英雄。',
    '杭州市',
    '2026-11-22T01:15:00+08:00'
),
(
    '00000000-0000-0000-0000-000000000103',
    'MOMENT',
    NULL,
    '周末原本泡好热茶准备静下心啃完半本书，结果只是低头回了条消息，一抬头窗外天已经黑透了。手机屏幕亮了三个小时，书页却停在第三十七页纹丝不动，当代人类专注力的天敌大概就是“我先看五分钟”。',
    '杭州市',
    '2026-11-22T14:20:00+08:00'
),
(
    '00000000-0000-0000-0000-000000000104',
    'MOMENT',
    NULL,
    '傍晚出门散步冷风嗖嗖往领口里钻，拐角刚好撞见一个老爷爷推着烤红薯车。花八块钱买了一块烫手的蜜薯，剥开焦香的外皮咬了一大口，突然觉得这个十一月也没有那么难熬了。',
    '苏州市',
    '2026-11-22T19:45:00+08:00'
),
(
    '00000000-0000-0000-0000-000000000105',
    'MOMENT',
    NULL,
    '周一早高峰的地铁像一个巨大的沙丁鱼罐头，大家戴着降噪耳机各自沉默，我盯着车窗外一闪而过的隧道广告牌发呆，突然很佩服那些还能在摇晃车厢里单手刷完一套算法题的人。',
    NULL,
    '2026-11-23T08:50:00+08:00'
),
(
    '00000000-0000-0000-0000-000000000106',
    'MOMENT',
    NULL,
    '中午点外卖堪称每日大型决策现场：在三十家店之间反复横跳、对比满减和配送费整整二十五分钟，最后还是稳稳下单了楼下那家吃了八十遍的猪脚饭。成年人的冒险精神在饿肚子面前不值一提。',
    '杭州市',
    '2026-11-23T12:30:00+08:00'
)
ON CONFLICT (id) DO NOTHING;

-- 3. 图片逻辑关联表（图片文件存 MinIO，post_id 逻辑关联 post.id）
CREATE TABLE IF NOT EXISTS post_image (
    id          VARCHAR(36)  PRIMARY KEY,
    post_id     VARCHAR(36),
    object_name VARCHAR(255) NOT NULL,
    sort_order  SMALLINT     NOT NULL DEFAULT 0,
    deleted     BOOLEAN      NOT NULL DEFAULT FALSE,
    created_at  TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);
ALTER TABLE post_image ADD COLUMN IF NOT EXISTS deleted BOOLEAN NOT NULL DEFAULT FALSE;
CREATE INDEX IF NOT EXISTS idx_post_image_post_id ON post_image (post_id);
