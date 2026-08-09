"""Domain enums for future backend domain models."""

from enum import Enum


class UserRole(str, Enum):
    USER = "user"
    CAREGIVER = "caregiver"
    ADMIN = "admin"
