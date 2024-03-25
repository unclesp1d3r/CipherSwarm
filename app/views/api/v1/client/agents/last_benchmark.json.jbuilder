json.last_benchmark_date @agent.last_benchmark_date.nil? ? (@agent.created_at - 365) : @agent.last_benchmark_date
