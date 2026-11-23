from drf_spectacular.contrib.rest_framework_simplejwt import SimpleJWTScheme


class KaamNowJWTScheme(SimpleJWTScheme):
    target_class = "apps.accounts.authentication.KaamNowJWTAuthentication"
    name = "jwtAuth"
