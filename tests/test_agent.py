# type: ignore
import pytest


class StubBenchmark:
    def __init__(self, hash_type_id, hash_speed=100.0):
        self.hash_type_id = hash_type_id
        self.hash_speed = hash_speed


class StubAgent:
    def __init__(self, benchmarks=None):
        self.benchmarks = benchmarks or []

    @property
    def benchmark_map(self):
        return {b.hash_type_id: b.hash_speed for b in self.benchmarks}

    def can_handle_hash_type(self, hash_type_id):
        return hash_type_id in self.benchmark_map


@pytest.mark.parametrize(
    "benchmarks,hash_type_id,expected",
    [
        ([StubBenchmark(100)], 100, True),
        ([StubBenchmark(100)], 200, False),
        ([], 100, False),
        (None, 100, False),
    ],
)
def test_agent_can_handle_hash_type(benchmarks, hash_type_id, expected):
    agent = StubAgent(benchmarks=benchmarks)
    assert agent.can_handle_hash_type(hash_type_id) is expected
