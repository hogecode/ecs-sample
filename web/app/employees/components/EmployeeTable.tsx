interface Employee {
  id: number;
  name: string;
  email: string;
  department: string;
  salary: string;
  created_at: string;
  updated_at: string;
}

interface EmployeeTableProps {
  employees: Employee[];
  loading: boolean;
  onEdit: (employee: Employee) => void;
  onDelete: (id: number) => void;
}

export function EmployeeTable({ employees, loading, onEdit, onDelete }: EmployeeTableProps) {
  if (loading) {
    return (
      <div className="text-center py-12">
        <p className="text-gray-600">読み込み中...</p>
      </div>
    );
  }

  return (
    <div className="bg-white rounded-lg shadow-lg overflow-hidden">
      <table className="w-full">
        <thead className="bg-gray-100 border-b border-gray-200">
          <tr>
            <th className="px-6 py-3 text-left text-sm font-semibold text-gray-900">ID</th>
            <th className="px-6 py-3 text-left text-sm font-semibold text-gray-900">名前</th>
            <th className="px-6 py-3 text-left text-sm font-semibold text-gray-900">メール</th>
            <th className="px-6 py-3 text-left text-sm font-semibold text-gray-900">部門</th>
            <th className="px-6 py-3 text-left text-sm font-semibold text-gray-900">給与</th>
            <th className="px-6 py-3 text-left text-sm font-semibold text-gray-900">アクション</th>
          </tr>
        </thead>
        <tbody>
          {employees.length === 0 ? (
            <tr>
              <td colSpan={6} className="px-6 py-4 text-center text-gray-500">
                従業員がいません
              </td>
            </tr>
          ) : (
            employees.map((employee) => (
              <tr key={employee.id} className="border-b border-gray-200 hover:bg-gray-50">
                <td className="px-6 py-4 text-sm text-gray-700">{employee.id}</td>
                <td className="px-6 py-4 text-sm text-gray-700">{employee.name}</td>
                <td className="px-6 py-4 text-sm text-gray-700">{employee.email}</td>
                <td className="px-6 py-4 text-sm text-gray-700">{employee.department}</td>
                <td className="px-6 py-4 text-sm text-gray-700">
                  ¥{parseFloat(employee.salary).toLocaleString('ja-JP')}
                </td>
                <td className="px-6 py-4 text-sm text-gray-700">
                  <div className="flex gap-2">
                    <button
                      onClick={() => onEdit(employee)}
                      className="bg-blue-500 hover:bg-blue-600 text-white px-2 py-1 rounded text-sm"
                    >
                      編集
                    </button>
                    <button
                      onClick={() => onDelete(employee.id)}
                      className="bg-red-500 hover:bg-red-600 text-white px-2 py-1 rounded text-sm"
                    >
                      削除
                    </button>
                  </div>
                </td>
              </tr>
            ))
          )}
        </tbody>
      </table>
      <div className="bg-gray-50 px-6 py-4 text-center text-gray-600 text-sm">
        <p>合計: {employees.length} 名</p>
      </div>
    </div>
  );
}
