from datetime import UTC, datetime

MONTHS_IN_YEAR = 12
MINUTES_IN_HOUR = 60
HOURS_IN_DAY = 24
DAYS_IN_WEEK = 7
WEEKS_IN_MONTH = 4

SI_UNIT_STEP = 1000

# NOTE: Filters are registered in templates.py


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


def humanize_speed(speed: float) -> str:
    """Format a hash speed as SI units (h/s, Kh/s, Mh/s, etc.)."""
    units = ["h/s", "Kh/s", "Mh/s", "Gh/s", "Th/s", "Ph/s"]
    value = speed
    unit = units[0]
    for u in units:
        if u != units[-1] and value >= SI_UNIT_STEP:
            value /= SI_UNIT_STEP
            unit = u
        else:
            break
    return f"{value:.2f} {unit}"
