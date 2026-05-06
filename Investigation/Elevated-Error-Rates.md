We noticed elevated 500 error rates from our platform. When looking at the logs, we saw messages that looked like this:

```
Elixir.DBConnection.ConnectionError: connection not available and request was dropped from queue after 219ms. 
This means requests are coming in and your connection pool cannot serve them fast enough. 
You can address this by:

1. Ensuring your database is available and that you can connect to it
2. Tracking down slow queries and making sure they are running fast enough
3. Increasing the pool_size (although this increases resource consumption)
4. Allowing requests to wait longer by increasing :queue_target and :queue_interval

See DBConnection.start_link/2 for more information
```

These error rates occurred after a recent deployment that introduced a feature querying against a new table. What direction would you take your investigation from here?

---

### My Thoughts

500 = Internal Server Error 

Key Point =  request was dropped from queue after 219ms

This means the DB should be up, but confirm to be sure.

If this queue is dropping after a new query, possible that the query is not efficent and filling the pool.

- Confirm DB is up, should be quick to confirm
- Log into Datadog and review the Database monitoring 
- Check slow query logs
- APM Traces for the time of the log/alert, check on the latency of the query end to end
- If the new query is confirmed as the cause, rollback is the right call for service restoration. Then fix forward with an index or query optimization before redeploying.

### Ai Enhancement 

- Check Ecto pool_size and queue_target settings in the repo config
- 219ms is the default queue_timeout, which is low for a high-value platform