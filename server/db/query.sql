-- name: GetEmployeeByID :one
SELECT id, name, email, department, salary, created_at, updated_at
FROM employees
WHERE id = ?;

-- name: ListEmployees :many
SELECT id, name, email, department, salary, created_at, updated_at
FROM employees
ORDER BY id DESC
LIMIT ? OFFSET ?;

-- name: CreateEmployee :exec
INSERT INTO employees (name, email, department, salary)
VALUES (?, ?, ?, ?);

-- name: UpdateEmployee :exec
UPDATE employees
SET name = ?, email = ?, department = ?, salary = ?, updated_at = CURRENT_TIMESTAMP
WHERE id = ?;

-- name: DeleteEmployee :exec
DELETE FROM employees
WHERE id = ?;
