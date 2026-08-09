"""Central exception helpers for backend error handling."""

class SmartMedReminderError(Exception):
    """Base application exception."""

    def __init__(self, message: str):
        self.message = message
        super().__init__(message)
