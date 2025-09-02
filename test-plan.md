# 測試計劃（手動＋腳本）— 從 Pod 自癒到壓測與告警驗證
_更新日期：2025-09-02_

涵蓋：**Pod 自動復原、節點故障、滾動更新、CrashLoop、CPU/記憶體壓力、HTTP 負載（hey/k6）、Alertmanager 路由測試、ServiceMonitor/Targets 檢查**。每項包含步驟、觀察重點與通過準則。

## 前置
- Grafana 有 15757/58/59/60/61/62/19105
- Prometheus Targets 為 `UP`
- `ServiceMonitor` 正確對應服務

## A. Pod 自動復原
```bash
NS=demo-local
DEPLOY=local-podinfo
POD=$(kubectl -n $NS get pod -l app=podinfo -o name | head -n1)
kubectl -n $NS delete $POD
kubectl -n $NS rollout status deploy/$DEPLOY
```
觀察：可用副本比恢復為 1；重啟不異常。

## B. 節點 NotReady（kind）
```bash
docker stop <kind-worker>
kubectl get nodes -w
# 復原：docker start <kind-worker>
```
觀察：節點轉 NotReady，恢復為 Ready；告警正確。

## C. 滾動更新
```bash
kubectl -n demo-local rollout restart deploy/local-podinfo
kubectl -n demo-local rollout status deploy/local-podinfo
```
觀察：不中斷、可用副本維持。

## D. CrashLoopBackOff
```yaml
apiVersion: v1
kind: Pod
metadata: { name: crash-demo, namespace: default }
spec:
  containers:
  - name: boom
    image: busybox
    command: ["sh","-c","echo bye; exit 1"]
```
觀察：重啟累積、告警觸發。

## E. CPU/記憶體壓力（短時）
```bash
kubectl -n default run cpu-stress --image=alpine/stress-ng --restart=Never -- --cpu 2 --timeout 60s
kubectl -n default run mem-stress --image=alpine/stress-ng --restart=Never -- --vm 1 --vm-bytes 200M --timeout 60s
```
觀察：資源曲線上升並回落；無 OOM。

## F. HTTP 壓力（hey / k6）
```bash
kubectl -n demo-local port-forward svc/local-podinfo 9898:9898 &
hey -z 60s -c 20 http://127.0.0.1:9898/
```
k6（叢集內）
```js
import http from 'k6/http'; import { sleep, check } from 'k6';
export const options = { vus: 20, duration: '1m' };
export default function () {
  const res = http.get(__ENV.TARGET || 'http://local-podinfo.demo-local.svc.cluster.local:9898/');
  check(res, { 'status 200': (r) => r.status === 200 });
  sleep(0.2);
}
```
（以 ConfigMap + Job 方式執行）

## G. Alertmanager 合成告警
```bash
ALERTMANAGER=http://127.0.0.1:9093
cat >/tmp/test-alert.json <<'JSON'
[{"labels":{"alertname":"SyntheticTest","severity":"warning"},"annotations":{"summary":"Synthetic test alert"},
"startsAt":"2025-09-02T00:00:00Z","endsAt":"2025-09-02T00:05:00Z"}]
JSON
curl -XPOST "$ALERTMANAGER/api/v2/alerts" -H 'Content-Type: application/json' -d @/tmp/test-alert.json
```

## H. ServiceMonitor/Targets
- `kubectl -n monitoring get servicemonitors.monitoring.coreos.com`
- `http://127.0.0.1:9090/targets`

## I. 驗收表（Pass/Fail）
| 測試 | 觀察重點 | 通過準則 |
|---|---|---|
| Pod 自復原 | 可用副本比、重啟 | 1 分鐘內恢復；重啟不異常 |
| 節點 NotReady | Ready 狀態、告警 | 準確 NotReady/Ready；告警正確 |
| 滾動更新 | 可用率 | 全程不中斷 |
| CrashLoop | 重啟/告警 | 觸發並自動回復 |
| CPU/Memory | 曲線 | 上升回落合理；無 OOM |
| HTTP 壓測 | 錯誤率/P95 | 低錯誤；P95 達標 |
| Alertmanager | 通知 | 各通道收到 |
| ServiceMonitor | Targets | 皆 `UP`，抓取耗時合理 |