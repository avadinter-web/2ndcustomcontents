from custom_content_studio.config import Environment, load_settings
def test_dev_root() -> None: assert load_settings(Environment.DEV).runtime_root.as_posix()==".runtime/DEV"
