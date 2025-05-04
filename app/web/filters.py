from datetime import UTC, datetime

MONTHS_IN_YEAR = 12
MINUTES_IN_HOUR = 60
HOURS_IN_DAY = 24
DAYS_IN_WEEK = 7
WEEKS_IN_MONTH = 4


def timeago(dt: datetime) -> str:  # noqa: PLR0911
    """Convert a datetime to a human-readable relative time string."""
    if not dt:
        return ""

    now = datetime.now(UTC)
    diff = now - dt

    seconds = int(diff.total_seconds())
    if seconds < MINUTES_IN_HOUR:
        return "just now"

    minutes = seconds // MINUTES_IN_HOUR
    if minutes < MINUTES_IN_HOUR:
        return f"{minutes}m ago"

    hours = minutes // MINUTES_IN_HOUR
    if hours < HOURS_IN_DAY:
        return f"{hours}h ago"

    days = hours // HOURS_IN_DAY
    if days < DAYS_IN_WEEK:
        return f"{days}d ago"

    weeks = days // DAYS_IN_WEEK
    if weeks < WEEKS_IN_MONTH:
        return f"{weeks}w ago"

    months = days // 30
    if months < MONTHS_IN_YEAR:
        return f"{months}mo ago"

    years = days // 365
    return f"{years}y ago"
