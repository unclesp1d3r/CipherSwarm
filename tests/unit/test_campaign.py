class StubAttack:
    def __init__(self, is_complete: bool) -> None:
        self.is_complete = is_complete


class StubCampaign:
    def __init__(self, attacks: list[StubAttack] | None = None) -> None:
        self.attacks = attacks or []

    @property
    def is_complete(self) -> bool:
        attacks = self.attacks or []
        if not attacks:
            return False
        return all(a.is_complete for a in attacks)


def test_campaign_is_complete_all_complete() -> None:
    attacks = [StubAttack(is_complete=True), StubAttack(is_complete=True)]
    campaign = StubCampaign(attacks=attacks)
    assert campaign.is_complete is True


def test_campaign_is_complete_some_incomplete() -> None:
    attacks = [StubAttack(is_complete=True), StubAttack(is_complete=False)]
    campaign = StubCampaign(attacks=attacks)
    assert campaign.is_complete is False


def test_campaign_is_complete_no_attacks() -> None:
    campaign = StubCampaign(attacks=[])
    assert campaign.is_complete is False
