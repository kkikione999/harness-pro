"""
隐藏测试用例 - 分布式订单管理系统
"""
import subprocess
import time
import requests
import signal
import os

ORDER_URL = "http://localhost:8081"
INVENTORY_URL = "http://localhost:8082"

def start_services():
    """启动两个服务"""
    os.chdir("/Users/josh_folder/harness-pro-for-vibe/harness-blogs/order-management-system")

    # 清理可能存在的进程
    for port in [8081, 8082]:
        try:
            result = subprocess.run(f"lsof -ti:{port} | xargs kill -9 2>/dev/null || true", shell=True)
        except:
            pass
    time.sleep(1)

    # 启动 Inventory Service
    inv_proc = subprocess.Popen(
        ["python3", "-m", "uvicorn", "inventory_service.main:app", "--host", "0.0.0.0", "--port", "8082"],
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        preexec_fn=os.setsid
    )

    # 启动 Order Service
    ord_proc = subprocess.Popen(
        ["python3", "-m", "uvicorn", "order_service.main:app", "--host", "0.0.0.0", "--port", "8081"],
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        preexec_fn=os.setsid
    )

    time.sleep(3)  # 等待服务启动
    return inv_proc, ord_proc

def stop_services(procs):
    """停止服务"""
    for proc in procs:
        try:
            os.killpg(os.getpgid(proc.pid), signal.SIGTERM)
        except:
            pass

def create_product(product_id, stock):
    """创建产品"""
    requests.post(f"{INVENTORY_URL}/products", json={"product_id": product_id, "stock": stock})

def reset_stock(product_id, stock):
    """重置库存"""
    requests.post(f"{INVENTORY_URL}/products/{product_id}/stock", json={"stock": stock})

def get_stock(product_id):
    """获取库存"""
    r = requests.get(f"{INVENTORY_URL}/products/{product_id}/stock")
    return r.json()

def create_order(user_id, items):
    """创建订单"""
    r = requests.post(f"{ORDER_URL}/orders", json={"user_id": user_id, "items": items})
    return r

def pay_order(order_id):
    """支付订单"""
    r = requests.post(f"{ORDER_URL}/orders/{order_id}/pay")
    return r

def cancel_order(order_id):
    """取消订单"""
    r = requests.post(f"{ORDER_URL}/orders/{order_id}/cancel")
    return r

def get_order(order_id):
    """获取订单"""
    r = requests.get(f"{ORDER_URL}/orders/{order_id}")
    return r

def run_tests():
    results = []

    # H1: 订单创建后正确调用 Inventory
    print("\n=== H1: 订单创建后正确调用Inventory ===")
    create_product("h1_product", 100)
    r1 = create_order("u1", [{"product_id": "h1_product", "quantity": 5}])
    if r1.status_code == 201:
        order_id = r1.json()["id"]
        stock = get_stock("h1_product")
        passed = stock["reserved_stock"] == 5
    else:
        passed = False
        print(f"  创建失败: {r1.status_code}, {r1.text}")
    results.append(("H1: 订单创建后正确调用Inventory", passed))
    print(f"  订单创建: {r1.status_code}, 库存预占: {get_stock('h1_product')['reserved_stock']}, 通过: {passed}")

    # H2: Inventory Service 宕机时 Order 能感知
    print("\n=== H2: Inventory Service 宕机感知 ===")
    create_product("h2_product", 100)
    # 停止 Inventory Service
    subprocess.run("lsof -ti:8082 | xargs kill -9 2>/dev/null || true", shell=True)
    time.sleep(2)
    r = create_order("u1", [{"product_id": "h2_product", "quantity": 1}])
    passed = r.status_code == 503
    results.append(("H2: Inventory宕机时Order返回503", passed))
    print(f"  Inventory宕机后创建订单状态码: {r.status_code}, 预期503, 通过: {passed}")

    # H3: 服务恢复后正常工作
    print("\n=== H3: 服务恢复后正常工作 ===")
    # 重启 Inventory
    inv_proc = subprocess.Popen(
        ["python3", "-m", "uvicorn", "inventory_service.main:app", "--host", "0.0.0.0", "--port", "8082"],
        stdout=subprocess.PIPE, stderr=subprocess.PIPE, preexec_fn=os.setsid
    )
    time.sleep(3)
    reset_stock("h3_product", 100)
    r = create_order("u1", [{"product_id": "h3_product", "quantity": 5}])
    passed = r.status_code == 201
    results.append(("H3: 服务正常时调用成功", passed))
    print(f"  创建订单状态码: {r.status_code}, 通过: {passed}")

    # H4: 预占失败时回滚
    print("\n=== H4: 预占失败时回滚 ===")
    create_product("h4_product", 2)  # 库存只有2
    r = create_order("u1", [{"product_id": "h4_product", "quantity": 5}])  # 预占5应该失败
    if r.status_code == 400:
        passed = True  # 直接拒绝
    else:
        # 如果订单创建了，验证库存未被预占
        stock = get_stock("h4_product")
        passed = stock["reserved_stock"] == 0
    results.append(("H4: 预占失败时库存不变", passed))
    print(f"  创建订单状态码: {r.status_code}, 库存预占: {get_stock('h4_product')['reserved_stock']}, 通过: {passed}")

    # H5: 重复支付防护
    print("\n=== H5: 重复支付防护 ===")
    create_product("h5_product", 100)
    r = create_order("u1", [{"product_id": "h5_product", "quantity": 1}])
    order_id = r.json()["id"]
    pay_order(order_id)  # 第一次
    r2 = pay_order(order_id)  # 第二次
    passed = r2.status_code == 400
    results.append(("H5: 重复支付返回错误", passed))
    print(f"  重复支付状态码: {r2.status_code}, 通过: {passed}")

    # H6: 超卖防护
    print("\n=== H6: 超卖防护 ===")
    create_product("h6_product", 5)
    r1 = create_order("u1", [{"product_id": "h6_product", "quantity": 3}])
    r2 = create_order("u2", [{"product_id": "h6_product", "quantity": 4}])

    stock = get_stock("h6_product")
    passed = (r1.status_code == 201 and r2.status_code == 400) or \
             (r1.status_code == 400 and r2.status_code == 201) or \
             (stock["reserved_stock"] <= 5 and stock["available_stock"] >= 0)
    results.append(("H6: 超卖防护", passed))
    print(f"  订单1: {r1.status_code}, 订单2: {r2.status_code}, 库存: {stock}, 通过: {passed}")

    # H7: 订单状态机 - paid 不能 cancel
    print("\n=== H7: 订单状态机 ===")
    create_product("h7_product", 100)
    r = create_order("u1", [{"product_id": "h7_product", "quantity": 1}])
    order_id = r.json()["id"]
    pay_order(order_id)  # 支付
    r_cancel = cancel_order(order_id)  # 尝试取消
    passed = r_cancel.status_code == 400
    results.append(("H7: paid状态不能取消", passed))
    print(f"  取消已支付订单状态码: {r_cancel.status_code}, 通过: {passed}")

    # H8: 不存在的订单返回 404
    print("\n=== H8: 不存在订单 ===")
    r = pay_order("NON_EXISTENT")
    passed = r.status_code == 404
    results.append(("H8: 不存在订单pay返回404", passed))
    print(f"  状态码: {r.status_code}, 通过: {passed}")

    r = cancel_order("NON_EXISTENT")
    passed = r.status_code == 404
    results.append(("H8: 不存在订单cancel返回404", passed))
    print(f"  取消不存在订单状态码: {r.status_code}, 通过: {passed}")

    # H9: 空订单防护
    print("\n=== H9: 空订单防护 ===")
    create_product("h9_product", 100)
    r = create_order("u1", {"items": []})
    passed = r.status_code in [400, 422]
    results.append(("H9: 空订单防护", passed))
    print(f"  创建空订单状态码: {r.status_code}, 通过: {passed}")

    # 汇总
    print("\n" + "="*50)
    print("隐藏测试结果汇总:")
    print("="*50)
    for name, passed in results:
        status = "✅ PASS" if passed else "❌ FAIL"
        print(f"  {status} {name}")

    passed_count = sum(1 for _, p in results if p)
    print(f"\n通过率: {passed_count}/{len(results)}")

    return results

if __name__ == "__main__":
    procs = start_services()
    try:
        run_tests()
    finally:
        stop_services(procs)
