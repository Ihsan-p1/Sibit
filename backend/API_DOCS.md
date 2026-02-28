# SIBIT APP - Backend API Documentation

The Flutter mobile application should communicate with this backend via the following REST APIs.

## 1. Authentication
**Endpoint:** `POST /api/login`
**Content-Type:** `application/x-www-form-urlencoded`
**Body:**
*   `username` (admin)
*   `password` (admin123)
**Response (200 OK):**
```json
{
  "access_token": "eyJhbGciOiJIUzI1NiIsInR5c... (JWT Token)",
  "token_type": "bearer",
  "role": "admin"
}
```
*Note: Save this `access_token` in Flutter's secure storage (e.g. `flutter_secure_storage`). Pass it as `Authorization: Bearer <token>` for protected routes.*

---

## 2. Get All Batches
**Endpoint:** `GET /api/batches`
**Auth Required:** No
**Response (200 OK):**
```json
{
  "status": "success",
  "data": [
    {
      "batch_id": "ABC-001",
      "varietas": "DxP Simalungun",
      "jumlah_awal": 1000,
      "jumlah_hidup": 1000,
      "tanggal_semai": "2024-05-12T10:00:00.000Z",
      "status": "prenursery",
      "is_verified": true,
      "nama_pekerja": "Budi"
    }
  ]
}
```

---

## 3. Worker: Add New Batch (Public)
**Endpoint:** `POST /api/batches/create`
**Content-Type:** `multipart/form-data` or `application/x-www-form-urlencoded`
**Auth Required:** No
**Body:**
*   `batch_id` (string)
*   `varietas` (string)
*   `jumlah_awal` (integer)
*   `lokasi` (string)
*   `nama_pekerja` (string) - *The name of the worker submitting this*
**Response (200 OK):**
```json
{
  "status": "success",
  "message": "Batch menunggu verifikasi",
  "batch_id": "ABC-001"
}
```

---

## 4. Worker: Update Batch & Scan QR (Public)
**Endpoint:** `POST /api/batches/update/{batch_id}`
**Content-Type:** `multipart/form-data`
**Auth Required:** No
**Body:**
*   `jumlah_hidup` (integer) - *The current living count*
*   `nama_pekerja` (string)
*   `catatan` (string, optional)
*   `photo` (file, optional) - *Image file from camera*
**Response (200 OK):**
```json
{
  "status": "success",
  "message": "Update berhasil direkam, menunggu verifikasi Admin."
}
```

---

## 5. Admin: Verify Submission (Protected)
**Endpoint:** `PUT /api/batches/verify/{batch_id}?action=approve` (or `action=reject`)
**Auth Required:** Yes (`Authorization: Bearer <token>`)
**Response (200 OK):**
```json
{
  "status": "success",
  "message": "Batch ABC-001 telah diverifikasi."
}
```
