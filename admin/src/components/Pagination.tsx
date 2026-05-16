interface Props {
  page: number;
  pages: number;
  total: number;
  limit: number;
  onChange: (p: number) => void;
}

export default function Pagination({ page, pages, total, limit, onChange }: Props) {
  if (pages <= 1) return null;

  const from = (page - 1) * limit + 1;
  const to = Math.min(page * limit, total);

  const nums: number[] = [];
  for (let i = Math.max(1, page - 2); i <= Math.min(pages, page + 2); i++) {
    nums.push(i);
  }

  return (
    <div className="pagination">
      <span className="pagination-info">
        {from}–{to} из {total}
      </span>
      <div className="pagination-buttons">
        <button disabled={page === 1} onClick={() => onChange(page - 1)}>←</button>
        {nums[0] > 1 && <button disabled>...</button>}
        {nums.map((n) => (
          <button key={n} className={n === page ? 'active' : ''} onClick={() => onChange(n)}>
            {n}
          </button>
        ))}
        {nums[nums.length - 1] < pages && <button disabled>...</button>}
        <button disabled={page === pages} onClick={() => onChange(page + 1)}>→</button>
      </div>
    </div>
  );
}
