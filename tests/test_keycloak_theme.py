import unittest
from pathlib import Path


INFRA_ROOT = Path(__file__).resolve().parents[1]
THEME_ROOT = INFRA_ROOT / "keycloak/themes/a-mesa/login"


class KeycloakThemeTest(unittest.TestCase):
    def test_theme_inherits_keycloak_v2_and_supports_pt_br(self) -> None:
        properties = (THEME_ROOT / "theme.properties").read_text()

        self.assertIn("parent=keycloak.v2", properties)
        self.assertIn("locales=pt-BR", properties)
        self.assertIn("styles=css/login.css", properties)

    def test_pt_br_covers_critical_identity_flows(self) -> None:
        messages = (THEME_ROOT / "messages/messages_pt_BR.properties").read_text()

        expected_keys = {
            "loginAccountTitle",
            "emailForgotTitle",
            "updatePasswordTitle",
            "loginProfileTitle",
            "loginOtpTitle",
            "verifyEmailTitle",
            "pageExpiredTitle",
            "errorTitle",
        }
        translated_keys = {
            line.split("=", 1)[0]
            for line in messages.splitlines()
            if line and not line.startswith("#") and "=" in line
        }

        self.assertTrue(expected_keys <= translated_keys)

    def test_compose_mounts_theme_read_only(self) -> None:
        compose = (INFRA_ROOT / "docker-compose.yml").read_text()

        self.assertIn(
            "./keycloak/themes/a-mesa:/opt/keycloak/themes/a-mesa:ro", compose
        )

    def test_v31_railway_image_contains_the_custom_theme(self) -> None:
        dockerfile = (INFRA_ROOT / "keycloak/Dockerfile").read_text()
        railway = (INFRA_ROOT / "keycloak/railway.json").read_text()

        self.assertIn(
            "COPY --chown=1000:0 themes/a-mesa /opt/keycloak/themes/a-mesa",
            dockerfile,
        )
        self.assertIn('"dockerfilePath": "Dockerfile"', railway)
        self.assertIn('"/themes/**"', railway)

    def test_provisioning_applies_theme_and_locale(self) -> None:
        provision = (INFRA_ROOT / "scripts/provision-keycloak.sh").read_text()

        self.assertIn('loginTheme:"a-mesa"', provision)
        self.assertIn("internationalizationEnabled:true", provision)
        self.assertIn('defaultLocale:"pt-BR"', provision)
        self.assertIn('supportedLocales:["pt-BR"]', provision)


if __name__ == "__main__":
    unittest.main()
