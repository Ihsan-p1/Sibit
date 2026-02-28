from sqlmodel import SQLModel, Field
from datetime import datetime
from typing import Optional

class User(SQLModel, table=True):
    id: Optional[int] = Field(default=None, primary_key=True)
    username: str = Field(index=True, unique=True)
    password_hash: str
    role: str = "admin" # admin, manager

class Batch(SQLModel, table=True):
    id: Optional[int] = Field(default=None, primary_key=True)
    batch_id: str = Field(index=True, unique=True)
    varietas: str
    jumlah_awal: int
    tanggal_semai: datetime
    status: str = "prenursery"  # prenursery / main nursery / siap jual
    jumlah_hidup: int
    is_verified: bool = Field(default=False)
    lokasi: str = Field(default="")
    nama_pekerja: str = Field(default="Sistem")
    
    @property
    def umur_hari(self) -> int:
        delta = datetime.utcnow() - self.tanggal_semai
        return delta.days
        
    @property
    def persentase_hidup(self) -> float:
        if self.jumlah_awal == 0:
            return 0.0
        return (self.jumlah_hidup / self.jumlah_awal) * 100

class AuditLog(SQLModel, table=True):
    id: Optional[int] = Field(default=None, primary_key=True)
    batch_id: str = Field(index=True)
    tanggal: datetime = Field(default_factory=datetime.utcnow)
    aksi: str
    nilai_lama: Optional[str] = None
    nilai_baru: Optional[str] = None
    keterangan: Optional[str] = None
    is_verified: bool = Field(default=False)
    nama_pekerja: str = Field(default="Sistem")

class BatchPhoto(SQLModel, table=True):
    id: Optional[int] = Field(default=None, primary_key=True)
    batch_id: str = Field(index=True)
    photo_path: str
    tanggal: datetime = Field(default_factory=datetime.utcnow)
    catatan: Optional[str] = None
