class_name Wind
extends RefCounted

## Глобальный ветер: направление и сила. Обновляется в main, читается накидкой.

static var direction := Vector3(0.8, 0.0, 0.6).normalized()
static var strength := 1.0
