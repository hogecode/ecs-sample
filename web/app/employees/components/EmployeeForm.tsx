import { useState } from 'react';

interface Employee {
  id: number;
  name: string;
  email: string;
  department: string;
  salary: string;
  created_at: string;
  updated_at: string;
}

interface EmployeeFormProps {
  show: boolean;
  editingId: number | null;
  formData: {
    name: string;
    email: string;
    department: string;
    salary: number;
  };
  onFormDataChange: (formData: { name: string; email: string; department: string; salary: number }) => void;
  onSubmit: (e: React.FormEvent) => Promise<void>;
  onCancel: () => void;
  employee?: Employee | null;
}

export function EmployeeForm({
  show,
  editingId,
  formData,
  onFormDataChange,
  onSubmit,
  onCancel,
}: EmployeeFormProps) {
  const [submitting, setSubmitting] = useState(false);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setSubmitting(true);
    try {
      await onSubmit(e);
    } finally {
      setSubmitting(false);
    }
  };

  if (!show) return null;

  return (
    <form onSubmit={handleSubmit} className="bg-white rounded-lg shadow-lg p-6 mb-8">
      <h2 className="text-2xl font-bold mb-4">
        {editingId ? '従業員を編集' : '新しい従業員を追加'}
      </h2>
      <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
        <div>
          <label className="block text-sm font-medium text-gray-700 mb-1">
            名前 *
          </label>
          <input
            type="text"
            required
            value={formData.name}
            onChange={(e) => onFormDataChange({ ...formData, name: e.target.value })}
            className="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
            disabled={submitting}
          />
        </div>
        <div>
          <label className="block text-sm font-medium text-gray-700 mb-1">
            メール *
          </label>
          <input
            type="email"
            required
            value={formData.email}
            onChange={(e) => onFormDataChange({ ...formData, email: e.target.value })}
            className="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
            disabled={submitting}
          />
        </div>
        <div>
          <label className="block text-sm font-medium text-gray-700 mb-1">
            部門 *
          </label>
          <input
            type="text"
            required
            value={formData.department}
            onChange={(e) => onFormDataChange({ ...formData, department: e.target.value })}
            className="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
            disabled={submitting}
          />
        </div>
        <div>
          <label className="block text-sm font-medium text-gray-700 mb-1">
            給与 *
          </label>
          <input
            type="number"
            required
            step="0.01"
            min="0"
            value={formData.salary}
            onChange={(e) => onFormDataChange({ ...formData, salary: parseFloat(e.target.value) })}
            className="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
            disabled={submitting}
          />
        </div>
      </div>
      <div className="flex gap-4 mt-6">
        <button
          type="submit"
          disabled={submitting}
          className="bg-blue-500 hover:bg-blue-600 disabled:bg-gray-400 text-white px-6 py-2 rounded-lg font-semibold"
        >
          {submitting ? '処理中...' : (editingId ? '更新' : '追加')}
        </button>
        <button
          type="button"
          onClick={onCancel}
          disabled={submitting}
          className="bg-gray-500 hover:bg-gray-600 disabled:bg-gray-400 text-white px-6 py-2 rounded-lg font-semibold"
        >
          キャンセル
        </button>
      </div>
    </form>
  );
}
