export const dynamic = 'force-dynamic';

import { fetchEmployees, deleteEmployee, createEmployee, updateEmployee } from '@/lib/api/api';
import { EmployeesClient } from './EmployeesClient';

interface Employee {
  id: number;
  name: string;
  email: string;
  department: string;
  salary: string;
  created_at: string;
  updated_at: string;
}

// サーバーアクション: 従業員作成
async function handleCreateEmployee(formData: {
  name: string;
  email: string;
  department: string;
  salary: number;
}) {
  'use server';
  try {
    await createEmployee(formData);
    return { success: true };
  } catch (err) {
    console.error(err);
    return { success: false, error: '従業員の作成に失敗しました' };
  }
}

// サーバーアクション: 従業員更新
async function handleUpdateEmployee(
  id: number,
  formData: {
    name: string;
    email: string;
    department: string;
    salary: number;
  }
) {
  'use server';
  try {
    await updateEmployee(id, formData);
    return { success: true };
  } catch (err) {
    console.error(err);
    return { success: false, error: '従業員の更新に失敗しました' };
  }
}

// サーバーアクション: 従業員削除
async function handleDeleteEmployee(id: number) {
  'use server';
  try {
    await deleteEmployee(id);
    return { success: true };
  } catch (err) {
    console.error(err);
    return { success: false, error: '従業員の削除に失敗しました' };
  }
}

export default async function EmployeesPage() {
  let initialEmployees: Employee[] = [];
  let error: string | null = null;

  try {
    const data = await fetchEmployees(100, 0);
    initialEmployees = data.data || [];
  } catch (err) {
    error = '従業員データの取得に失敗しました';
    console.error(err);
  }

  return (
    <main className="min-h-screen bg-gray-50 p-8">
      {error && (
        <div className="max-w-7xl mx-auto mb-8">
          <div className="bg-red-100 border border-red-400 text-red-700 px-4 py-3 rounded">
            {error}
          </div>
        </div>
      )}
      <EmployeesClient 
        initialEmployees={initialEmployees}
        onCreateEmployee={handleCreateEmployee}
        onUpdateEmployee={handleUpdateEmployee}
        onDeleteEmployee={handleDeleteEmployee}
      />
    </main>
  );
}
