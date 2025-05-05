# type: ignore


class StubTask:
    def __init__(self, progress_percent=0.0, result_submitted=False):
        self.progress_percent = progress_percent
        self.result_submitted = result_submitted

    @property
    def is_complete(self):
        return self.progress_percent == 100.0 or self.result_submitted


def test_task_is_complete_by_progress():
    task = StubTask(progress_percent=100.0, result_submitted=False)
    assert task.is_complete is True


def test_task_is_complete_by_result():
    task = StubTask(progress_percent=50.0, result_submitted=True)
    assert task.is_complete is True


def test_task_is_not_complete():
    task = StubTask(progress_percent=50.0, result_submitted=False)
    assert task.is_complete is False
