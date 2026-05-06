import { expect, test } from '@playwright/test';

test.describe('InvoiceFlow static shell', () => {
  test('login screen and InvoiceFlow title load', async ({ page }) => {
    await page.goto('/invoicing-tool.html');
    await expect(page.getByText('InvoiceFlow', { exact: true }).first()).toBeVisible();
    await expect(page.getByRole('button', { name: 'Sign In' })).toBeVisible();
  });
});
