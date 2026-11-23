from rest_framework import exceptions
from rest_framework_simplejwt.authentication import JWTAuthentication


class KaamNowJWTAuthentication(JWTAuthentication):
    """JWT authentication that also blocks suspended accounts immediately."""

    def get_user(self, validated_token):
        user = super().get_user(validated_token)
        if user.is_suspended:
            raise exceptions.AuthenticationFailed("This account is suspended.", code="account_suspended")
        return user
