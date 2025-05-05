# type: ignore


class StubAttack:
    def __init__(self, is_complete: bool):
        self.is_complete = is_complete


class StubCampaign:
    def __init__(self, attacks=None):
        self.attacks = attacks or []

    @property
    def is_complete(self):
        attacks = self.attacks or []
        if not attacks:
            return False
        return all(a.is_complete for a in attacks)


def test_campaign_is_complete_all_complete():
    attacks = [StubAttack(True), StubAttack(True)]
    campaign = StubCampaign(attacks=attacks)
    assert campaign.is_complete is True


def test_campaign_is_complete_some_incomplete():
    attacks = [StubAttack(True), StubAttack(False)]
    campaign = StubCampaign(attacks=attacks)
    assert campaign.is_complete is False


def test_campaign_is_complete_no_attacks():
    campaign = StubCampaign(attacks=[])
    assert campaign.is_complete is False
