'use client';

import { useState } from 'react';
import { ErrorAlert } from './components/ErrorAlert';
import { EmployeeForm } from './components/EmployeeForm';
import { EmployeeTable } from './components/EmployeeTable';

interface Employee {
  id: number;
  name: string;
  email: string;
  department: string;
  salary: string;
  created_at: string;
  updated_at: string;
}

interface EmployeesClientProps {
  initialEmployees: Employee[];
  onCreateEmployee: (formData: {
    name: string;
    email: string;
    department: string;
    salary: number;
  }) => Promise<{ success: boolean; error?: string }>;
  onUpdateEmployee: (
    id: number,
    formData: {
      name: string;
      email: string;
      department: string;
      salary: number;
    }
  ) => Promise<{ success: boolean; error?: string }>;
  onDeleteEmployee: (id: number) => Promise<{ success: boolean; error?: string }>;
}

export function EmployeesClient({
  initialEmployees,
  onCreateEmployee,
  onUpdateEmployee,
  onDeleteEmployee,
}: EmployeesClientProps) {
  const [employees, setEmployees] = useState<Employee[]>(initialEmployees);
  const [error, setError] = useState<string | null>(null);
  const [showForm, setShowForm] = useState(false);
  const [editingId, setEditingId] = useState<number | null>(null);
  const [formData, setFormData] = useState({
    name: '',
    email: '',
    department: '',
    salary: 0,
  });

  // フォーム送信
  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    try {
      let result;
      if (editingId) {
        result = await onUpdateEmployee(editingId, formData);
      } else {
        result = await onCreateEmployee(formData);
      }
      
      if (!result.success) {
        setError(result.error || '操作に失敗しました');
        return;
      }

      setFormData({ name: '', email: '', department: '', salary: 0 });
      setShowForm(false);
      setEditingId(null);
      // リロード処理
      window.location.reload();
    } catch (err) {
      setError('操作に失敗しました');
      console.error(err);
    }
  };

  // 削除
  const handleDelete = async (id: number) => {
    if (!confirm('削除してもよろしいですか？')) return;
    try {
      const result = await onDeleteEmployee(id);
      if (!result.success) {
        setError(result.error || '削除に失敗しました');
        return;
      }
      setEmployees(employees.filter(e => e.id !== id));
      setError(null);
    } catch (err) {
      setError('削除に失敗しました');
      console.error(err);
    }
  };

  // 編集開始
  const handleEdit = (employee: Employee) => {
    setEditingId(employee.id);
    setFormData({
      name: employee.name,
      email: employee.email,
      department: employee.department,
      salary: parseFloat(employee.salary),
    });
    setShowForm(true);
  };

  // フォームキャンセル
  const handleCancel = () => {
    setShowForm(false);
    setEditingId(null);
    setFormData({ name: '', email: '', department: '', salary: 0 });
  };

  return (
    <div className="max-w-7xl mx-auto">
      <div className="flex justify-between items-center mb-8">
        <h1 className="text-4xl font-bold text-gray-900">従業員管理</h1>
        <button
          onClick={() => {
            setShowForm(!showForm);
            if (showForm) {
              handleCancel();
            }
          }}
          className="bg-green-500 hover:bg-green-600 text-white px-6 py-2 rounded-lg font-semibold"
        >
          {showForm ? 'キャンセル' : '新規追加'}
        </button>
      </div>

      <ErrorAlert error={error} />

      <EmployeeForm
        show={showForm}
        editingId={editingId}
        formData={formData}
        onFormDataChange={setFormData}
        onSubmit={handleSubmit}
        onCancel={handleCancel}
      />

      <EmployeeTable
        employees={employees}
        loading={false}
        onEdit={handleEdit}
        onDelete={handleDelete}
      />
    </div>
  );
}
