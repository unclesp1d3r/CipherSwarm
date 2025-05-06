# type: ignore  # noqa: PGH003


class StubTask:
    def __init__(
        self, progress_percent: float = 0.0, result_submitted: bool = False
    ) -> None:
        self.progress_percent = progress_percent
        self.result_submitted = result_submitted

    @property
    def is_complete(self) -> bool:
        HUNDRED_PERCENT = 100.0  # noqa: N806
        return self.progress_percent == HUNDRED_PERCENT or self.result_submitted


def test_task_is_complete_by_progress() -> None:
    task = StubTask(progress_percent=100.0, result_submitted=False)
    assert task.is_complete is True


def test_task_is_complete_by_result() -> None:
    task = StubTask(progress_percent=50.0, result_submitted=True)
    assert task.is_complete is True


def test_task_is_not_complete() -> None:
    task = StubTask(progress_percent=50.0, result_submitted=False)
    assert task.is_complete is False
