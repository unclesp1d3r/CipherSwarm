# mypy: disable-error-code=import
from typing import Any

import pytest


class StubAgent:
    def __init__(
        self,
        benchmarks: list[Any] | None = None,
        can_handle: bool = True,
        agent_id: int = 1,
    ) -> None:
        self.benchmarks = benchmarks
        self._can_handle = can_handle
        self.id = agent_id

    def can_handle_hash_type(self) -> bool:
        return self._can_handle


class StubAttack:
    def __init__(self, hash_type_id: int = 100) -> None:
        self.hash_type_id = hash_type_id


class StubTask:
    def __init__(
        self,
        keyspace_total: int = 100,
        agent_id: int | None = None,
        status: str = "pending",
        attack: Any = None,
    ) -> None:
        self.keyspace_total = keyspace_total
        self.agent_id = agent_id
        self.status = status
        self.attack = attack or StubAttack()


@pytest.fixture
def stub_assigner() -> Any:
    # Simulate the assignment logic as a function
    def assign(
        agent: StubAgent, tasks: list[StubTask], running_task: StubTask | None = None
    ) -> StubTask | None:
        if not agent.benchmarks:
            return None
        if running_task:
            return None
        for task in tasks:
            if task.keyspace_total <= 0:
                continue
            if task.agent_id is not None:
                continue
            if agent.can_handle_hash_type():
                task.agent_id = agent.id
                task.status = "running"
                return task
        return None

    return assign


def test_assign_compatible_task(stub_assigner: Any) -> None:
    agent = StubAgent(benchmarks=[1], can_handle=True)
    tasks = [StubTask(keyspace_total=100)]
    assigned = stub_assigner(agent, tasks)
    assert assigned is tasks[0]
    assert assigned.status == "running"
    assert assigned.agent_id == agent.id


def test_assign_no_matching_benchmark(stub_assigner: Any) -> None:
    agent = StubAgent(benchmarks=[1], can_handle=False)
    tasks = [StubTask(keyspace_total=100)]
    assigned = stub_assigner(agent, tasks)
    assert assigned is None


def test_assign_no_benchmarks(stub_assigner: Any) -> None:
    agent = StubAgent(benchmarks=None)
    tasks = [StubTask(keyspace_total=100)]
    assigned = stub_assigner(agent, tasks)
    assert assigned is None


def test_assign_zero_keyspace(stub_assigner: Any) -> None:
    agent = StubAgent(benchmarks=[1], can_handle=True)
    tasks = [StubTask(keyspace_total=0)]
    assigned = stub_assigner(agent, tasks)
    assert assigned is None


def test_assign_already_assigned(stub_assigner: Any) -> None:
    agent = StubAgent(benchmarks=[1], can_handle=True)
    tasks = [StubTask(keyspace_total=100, agent_id=2)]
    assigned = stub_assigner(agent, tasks)
    assert assigned is None


def test_assign_agent_with_active_task(stub_assigner: Any) -> None:
    agent = StubAgent(benchmarks=[1], can_handle=True)
    tasks = [StubTask(keyspace_total=100)]
    running_task = StubTask(keyspace_total=100, agent_id=agent.id, status="running")
    assigned = stub_assigner(agent, tasks, running_task=running_task)
    assert assigned is None
