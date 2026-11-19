# Dependency audit — 2026-11-19

Run by the orchestrator with `bundle-audit check --update` against `Gemfile.lock` as it
stands on `claude/redesign-programme` (the lockfile is unchanged by this programme, so this
is also the state of production). CI did not catch this: in `.github/workflows/ci.yml` the
`bundle-audit` step runs after Brakeman in the same job, and Brakeman fails on the Rails
end-of-life warning, so the audit step has been **skipped** on every run.

**Result: 79 advisories** — 1 Critical, 8 High, 26 Medium, 12 Low, 32 Unknown severity.

**Fix: merge wsethbrown/wss#36 first.** It moves Rails 8.0.5 → 8.1.4.1 and updates rack,
nokogiri, puma, omniauth, addressable, json, msgpack, net-ssh and rubyzip (2 → 3.x), and
reports `bundle-audit` clean. This programme deliberately makes no lockfile changes so the
two PRs do not conflict. If the owner declines the Rails 8.1 jump, a patch-only update
(Rails 8.0.5.2 plus the gems below) is the fallback, done on #36's branch or a fresh one.
B18 makes the audit run even when Brakeman fails.

| Gem | Version | Severities | Advisories |
|---|---|---|---|
| actionmailbox | 8.0.5 | Low | GHSA-5957-c7qm-m469 |
| actionpack | 8.0.5 | High, Low, Medium | GHSA-2586-8ghr-69fj, GHSA-gmj8-hvj3-49mw, GHSA-r9jg-fmfx-2gv6, GHSA-rwvh-fw6r-pwvp, GHSA-wm3x-v3qw-4jh3, GHSA-x6mj-8jx9-qhqv |
| actionview | 8.0.5 | Medium | GHSA-2p2f-4rq4-gjwc, GHSA-68p9-83h6-5wpj, GHSA-rq8q-p985-fjq7, GHSA-v6rj-xm57-3p59 |
| activestorage | 8.0.5 | Critical, High, Low, Medium, Unknown | GHSA-xr9x-r78c-5hrm, GHSA-3f4q-8x5m-76v8, GHSA-3w93-6hmw-whh4, GHSA-4v2w-w6g6-f8f8, GHSA-f3w6-w445-fwh9, GHSA-hfr4-8rjc-97m2, GHSA-p2pm-g2h6-7j5j, GHSA-v924-7rp8-4mxh |
| activesupport | 8.0.5 | High | GHSA-8474-xrp6-wh69 |
| addressable | 2.9.0 | Low, Medium | GHSA-4w5q-wg7v-w6gp, GHSA-539f-xcgw-2gjg, GHSA-8gmh-2hhj-2hv9, GHSA-9crm-g4mf-wc5j, GHSA-9f42-57jx-vpp3, GHSA-j82w-28jv-3pmj, GHSA-qq38-m9mg-xjj5 |
| crass | 1.0.7 | Unknown | GHSA-pq4g-8rxf-4g29 |
| json | 2.21.1 | Unknown | GHSA-9hj4-r449-hfvc |
| loofah | 2.25.2 | Medium, Unknown | GHSA-345x-3rq2-jfrm, GHSA-h6v6-rg66-fqj4, GHSA-jcff-cj73-4w4f, GHSA-m3x9-938q-5767, GHSA-mf2j-8f84-cc9q, GHSA-p9wj-w8xq-vjx6 |
| msgpack | 1.8.3 | High | GHSA-73v3-wf97-vpgj |
| net-ssh | 7.3.3 | High, Unknown | GHSA-3x7f-q7wf-fp73, GHSA-ggxh-cfwq-5xqc, GHSA-pfqh-p9vh-wx4p, GHSA-qpg5-fx6p-8cq3, GHSA-r75w-7fhp-84w8, GHSA-rpq3-v334-f5pm, GHSA-vxj5-fg65-x765 |
| nokogiri | 1.19.4 | Low, Unknown | GHSA-3w22-6jfg-527w, GHSA-4p39-36wj-23h4, GHSA-v995-44v6-5fqm, GHSA-3w22-6jfg-527w, GHSA-4p39-36wj-23h4, GHSA-v995-44v6-5fqm, GHSA-3w22-6jfg-527w, GHSA-4p39-36wj-23h4, GHSA-v995-44v6-5fqm, GHSA-3w22-6jfg-527w, GHSA-4p39-36wj-23h4, GHSA-v995-44v6-5fqm, GHSA-3w22-6jfg-527w, GHSA-4p39-36wj-23h4, GHSA-v995-44v6-5fqm, GHSA-3w22-6jfg-527w, GHSA-4p39-36wj-23h4, GHSA-v995-44v6-5fqm, GHSA-3w22-6jfg-527w, GHSA-4p39-36wj-23h4, GHSA-v995-44v6-5fqm |
| omniauth | 2.1.4 | Unknown | GHSA-m27g-v28p-f9fx |
| puma | 8.0.2 | Unknown | GHSA-86xc-wrr9-xmmq, GHSA-jm4r-w4xx-qxw7, GHSA-m5xw-3hrw-qcmf, GHSA-r885-m39c-939g, GHSA-rf6g-xhmp-gm7v, GHSA-x646-wp7c-h9mg, GHSA-xw3h-pgr9-3vg7 |
| rack | 3.2.6 | High, Low, Medium | GHSA-2j8w-xcrc-x985, GHSA-5v64-555j-wjxm, GHSA-p8x9-v4hv-2w4g, GHSA-wvg4-6p58-3gh3 |
| rails-html-sanitizer | 1.7.1 | Medium | GHSA-cpgf-5mjf-73p7, GHSA-h7wh-q2qr-458c |
| rubyzip | 2.4.1 | High | GHSA-47m2-wp7j-p9vc |
