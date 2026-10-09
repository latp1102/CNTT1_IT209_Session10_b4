# Bài 4 - Thiết lập Custom Network & Named Volume bằng Docker CLI

## 1. Mục tiêu

Thiết lập cụm 2 Container bằng Docker CLI thủ công:

* Backend Container: `app-container`
* PostgreSQL Database Container: `db-server`
* Custom Bridge Network: `app-net`
* Named Volume: `db-data`

Mục tiêu:

* Các Container giao tiếp với nhau thông qua Custom Bridge Network.
* Backend có thể phân giải hostname `db-server` thông qua Docker DNS.
* PostgreSQL sử dụng Named Volume để lưu trữ dữ liệu bền vững.
* Dữ liệu Database không bị mất khi xóa và tạo lại Container Database.

---

## 2. Tạo Custom Bridge Network

Tạo Network có tên `app-net`:

```bash
docker network create --driver bridge app-net
```

Kiểm tra:

```bash
docker network ls | grep app-net
```

Kết quả mong đợi:

```text
app-net
```

---

## 3. Tạo Named Volume

Tạo Named Volume có tên `db-data`:

```bash
docker volume create db-data
```

Kiểm tra:

```bash
docker volume ls | grep db-data
```

Kết quả mong đợi:

```text
db-data
```

---

## 4. Khởi chạy PostgreSQL Database Container

Khởi chạy PostgreSQL 15 Alpine với:

* Tên Container: `db-server`
* Network: `app-net`
* Database: `appdb`
* User: `appuser`
* Password: `apppass`
* Named Volume: `db-data`

Lệnh:

```bash
docker run -d \
  --name db-server \
  --network app-net \
  -e POSTGRES_DB=appdb \
  -e POSTGRES_USER=appuser \
  -e POSTGRES_PASSWORD=apppass \
  -v db-data:/var/lib/postgresql/data \
  postgres:15-alpine
```

Kiểm tra Container:

```bash
docker ps
```

Kết quả phải có Container:

```text
db-server
```

---

## 5. Khởi chạy Backend Container

Khởi chạy Backend Container và kết nối vào cùng Network `app-net`.

Các biến môi trường kết nối Database:

```text
DB_HOST=db-server
DB_PORT=5432
DB_NAME=appdb
DB_USER=appuser
DB_PASSWORD=apppass
```

Lệnh:

```bash
docker run -d \
  --name app-container \
  --network app-net \
  -e DB_HOST=db-server \
  -e DB_PORT=5432 \
  -e DB_NAME=appdb \
  -e DB_USER=appuser \
  -e DB_PASSWORD=apppass \
  alpine:3.20 \
  sh -c "while true; do sleep 3600; done"
```

Kiểm tra:

```bash
docker ps
```

Kết quả phải có:

```text
db-server
app-container
```

---

## 6. Kiểm tra Custom Network

Kiểm tra Network:

```bash
docker network inspect app-net
```

Trong phần `Containers` phải có:

```text
db-server
app-container
```

Điều này chứng minh cả Database Container và Backend Container đều tham gia Custom Network `app-net`.

---

## 7. Kiểm tra DNS Resolution

Từ Backend Container, kiểm tra khả năng phân giải hostname `db-server`:

```bash
docker exec -it app-container ping -c 2 db-server
```

Kết quả mong đợi:

```text
PING db-server (172.xx.xx.xx)
64 bytes from 172.xx.xx.xx: seq=0 ttl=64 time=...
64 bytes from 172.xx.xx.xx: seq=1 ttl=64 time=...
```

Điều này chứng minh:

```text
app-container
      |
      | Docker DNS
      v
db-server
      |
      v
IP nội bộ của Database Container
```

Backend không cần sử dụng IP cố định của Database Container mà có thể sử dụng hostname `db-server`.

---

# 8. Test Data Persistence

## 8.1. Tạo bảng và dữ liệu

Truy cập PostgreSQL Container:

```bash
docker exec -it db-server psql -U appuser -d appdb
```

Tạo bảng `users`:

```sql
CREATE TABLE users (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100)
);
```

Thêm dữ liệu:

```sql
INSERT INTO users (name) VALUES ('Phong');
```

Kiểm tra dữ liệu:

```sql
SELECT * FROM users;
```

Kết quả mong đợi:

```text
 id | name
----+-------
  1 | Phong
```

Thoát PostgreSQL:

```sql
\q
```

---

## 8.2. Xóa cứng Database Container

Xóa Container Database:

```bash
docker rm -f db-server
```

Kiểm tra:

```bash
docker ps
```

Container `db-server` không còn tồn tại.

Kiểm tra Named Volume:

```bash
docker volume ls | grep db-data
```

Kết quả vẫn phải có:

```text
db-data
```

Điều này chứng minh việc xóa Container không xóa Named Volume.

---

## 8.3. Khởi chạy lại Database Container

Tạo lại Container Database và sử dụng lại Named Volume `db-data`:

```bash
docker run -d \
  --name db-server \
  --network app-net \
  -e POSTGRES_DB=appdb \
  -e POSTGRES_USER=appuser \
  -e POSTGRES_PASSWORD=apppass \
  -v db-data:/var/lib/postgresql/data \
  postgres:15-alpine
```

Chờ PostgreSQL khởi động:

```bash
sleep 10
```

Kiểm tra:

```bash
docker ps
```

Container `db-server` đã được tạo lại.

---

## 8.4. Xác minh dữ liệu không bị mất

Truy cập Database:

```bash
docker exec -it db-server psql -U appuser -d appdb
```

Kiểm tra dữ liệu:

```sql
SELECT * FROM users;
```

Kết quả mong đợi:

```text
 id | name
----+-------
  1 | Phong
```

Dữ liệu `Phong` vẫn tồn tại mặc dù Container Database cũ đã bị xóa.

Thoát PostgreSQL:

```sql
\q
```

---

# 9. Kiểm tra toàn bộ hệ thống

## 9.1. Kiểm tra Network

```bash
docker network ls | grep app-net
```

Kết quả:

```text
app-net
```

---

## 9.2. Kiểm tra Volume

```bash
docker volume ls | grep db-data
```

Kết quả:

```text
db-data
```

---

## 9.3. Kiểm tra Network Details

```bash
docker network inspect app-net
```

Phải có:

```text
db-server
app-container
```

---

## 9.4. Kiểm tra DNS

```bash
docker exec -it app-container ping -c 2 db-server
```

Ping phải thành công.

---

## 9.5. Kiểm tra Container

```bash
docker ps
```

Phải có:

```text
db-server
app-container
```

---

# 10. Kết quả đạt được

Sau khi thực hiện bài thực hành:

* Custom Bridge Network `app-net` được tạo thành công.
* Named Volume `db-data` được tạo thành công.
* PostgreSQL Container `db-server` chạy trên Network `app-net`.
* Backend Container `app-container` chạy trên Network `app-net`.
* Backend có thể phân giải hostname `db-server`.
* PostgreSQL lưu dữ liệu vào Named Volume `db-data`.
* Khi xóa Container `db-server`, dữ liệu không bị mất.
* Khi tạo lại Container `db-server` và mount lại `db-data`, dữ liệu cũ vẫn còn.

---

# 11. Files nộp bài

Thư mục bài:

```text
Session10/b4/
```

Các file cần nộp:

```text
Session10/b4/
├── commands.sh
└── README.md
```

Trong đó:

* `commands.sh`: chứa các lệnh Docker CLI để thiết lập hệ thống.
* `README.md`: mô tả quá trình thực hiện, kiểm tra Network, DNS và Data Persistence.
