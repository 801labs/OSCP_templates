# Redis - <% tp.frontmatter.current_port %>

## Different exploit paths

### Having write access to server AND access to redis
https://github.com/n0b0dyCN/RedisModules-ExecuteCommand


### If redis it less than 5.0.9 still check if its above, you never know.

https://github.com/n0b0dyCN/redis-rogue-server

### Possible location for info on redis server
```directory
/etc/systemd/system/redis.service
```
