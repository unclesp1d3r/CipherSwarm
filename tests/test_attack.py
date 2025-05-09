# mypy: disable-error-code=import

from typing import Any


class StubTask:
    def __init__(self, progress_percent: float, keyspace_total: int) -> None:
        self.progress_percent = progress_percent
        self.keyspace_total = keyspace_total


class StubAttack:
    def __init__(self, tasks: list[Any] | None = None) -> None:
        self.tasks = tasks or []

    @property
    def progress_percent(self) -> float:
        tasks = self.tasks or []
        if not tasks:
            return 0.0
        total_keyspace = float(sum(float(t.keyspace_total) for t in tasks))
        if total_keyspace > 0:
            weighted_sum = float(
                sum(
                    (float(t.progress_percent) / 100.0) * float(t.keyspace_total)
                    for t in tasks
                )
            )
            return weighted_sum / total_keyspace * 100.0
        return float(sum(float(t.progress_percent) for t in tasks)) / float(len(tasks))


class StubTaskWithComplete:
    def __init__(self, is_complete: bool) -> None:
        self.is_complete = is_complete


class StubAttackWithComplete:
    def __init__(self, tasks: list[Any] | None = None) -> None:
        self.tasks = tasks or []

    @property
    def is_complete(self) -> bool:
        tasks = self.tasks or []
        if not tasks:
            return False
        return all(t.is_complete for t in tasks)


# Magic values for test assertions
PROGRESS_AVG: float = 50.0
PROGRESS_WEIGHTED: float = 25.0


def test_attack_progress_equal_keyspace() -> None:
    tasks = [StubTask(50, 100), StubTask(100, 100), StubTask(0, 100)]
    attack = StubAttack(tasks=tasks)
    # Average: (50+100+0)/3 = 50.0
    assert attack.progress_percent == PROGRESS_AVG


def test_attack_progress_unequal_keyspace() -> None:
    tasks = [StubTask(50, 100), StubTask(100, 200), StubTask(0, 700)]
    attack = StubAttack(tasks=tasks)
    # Weighted: (50/100*100 + 100/100*200 + 0/100*700) = (50+200+0)=250; total=1000; 250/1000*100=25.0
    assert attack.progress_percent == PROGRESS_WEIGHTED


def test_attack_progress_no_tasks() -> None:
    attack = StubAttack(tasks=[])
    assert attack.progress_percent == 0.0


def test_attack_is_complete_all_complete() -> None:
    tasks = [StubTaskWithComplete(True), StubTaskWithComplete(True)]
    attack = StubAttackWithComplete(tasks=tasks)
    assert attack.is_complete is True


def test_attack_is_complete_some_incomplete() -> None:
    tasks = [StubTaskWithComplete(True), StubTaskWithComplete(False)]
    attack = StubAttackWithComplete(tasks=tasks)
    assert attack.is_complete is False


def test_attack_is_complete_no_tasks() -> None:
    attack = StubAttackWithComplete(tasks=[])
    assert attack.is_complete is False
