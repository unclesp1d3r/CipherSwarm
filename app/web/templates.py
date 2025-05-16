from fastapi.templating import Jinja2Templates
from fasthx import Jinja

from app.web import filters

# Set up Jinja2Templates and register custom filters
_templates = Jinja2Templates(directory="templates")
_templates.env.filters["timeago"] = filters.timeago

# Create the FastHX Jinja instance
jinja = Jinja(_templates)
