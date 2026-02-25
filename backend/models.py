from sqlmodel import SQLModel, Field
from datetime import datetime
from typing import Optional

class Batch(SQLModel, table=True):
    id: Optional[int] = Field(default=None, primary_key=True)
    batch_id: str = Field(index=True, unique=True)
    tanggal_semai: datetime = Field(default_factory=datetime.utcnow)
    varietas: str
    jumlah_awal: int
    lokasi_bedeng: str
    status: str = "prenursery"  # prenursery / main nursery / siap jual
    jumlah_hidup: int
    qr_path: Optional[str] = None
    
    @property
    def umur_hari(self) -> int:
        delta = datetime.utcnow() - self.tanggal_semai
        return delta.days

    @property
    def sisa_hari_siap_jual(self) -> int:
        target_hari = 90  # Asumsi standar nursery
        sisa = target_hari - self.umur_hari
        return max(0, sisa)

    @property
    def kesehatan_status(self) -> str:
        # Hijau: > 90%, Kuning: 70-90%, Merah: < 70%
        if self.jumlah_awal <= 0: return "unknown"
        rate = (self.jumlah_hidup / self.jumlah_awal) * 100
        if rate >= 90: return "sehat"
        if rate >= 70: return "perlu_perhatian"
        return "kritis"

    @property
    def persentase_hidup(self) -> float:
        if self.jumlah_awal <= 0:
            return 0.0
        return (self.jumlah_hidup / self.jumlah_awal) * 100

class AuditLog(SQLModel, table=True):
    id: Optional[int] = Field(default=None, primary_key=True)
    batch_id: str = Field(index=True)
    tanggal: datetime = Field(default_factory=datetime.utcnow)
    aksi: str  # e.g., "Update Mortality", "Status Change"
    nilai_lama: Optional[str] = None
    nilai_baru: Optional[str] = None
    keterangan: Optional[str] = None

class BatchPhoto(SQLModel, table=True):
    id: Optional[int] = Field(default=None, primary_key=True)
    batch_id: str = Field(index=True)
    tanggal: datetime = Field(default_factory=datetime.utcnow)
    photo_path: str
    catatan: Optional[str] = None
