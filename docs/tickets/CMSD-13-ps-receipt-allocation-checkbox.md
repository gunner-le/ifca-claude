# CMSD-13 — Receivable Collection: không tick được checkbox allocation

- **Client:** CMSD (môi trường `CMSP_Train`)
- **Module:** Property Sales > Account Receivable > AR Transaction > Receivable > Add (Receivable Collection Screen)
- **File:** `PSAccount/PSReceiptAdd.aspx` (JS), code-behind `PSReceiptAdd.aspx.cs` (không đổi)
- **Ngày:** 2026-10-21
- **Trạng thái:** Đã fix & test OK trên Train (Save receipt `TB/OR000003` thành công). Chờ deploy Live.

## 1. Bối cảnh

Màn Receivable Collection, tab Invoice Detail (`SysList1`, `LstNo = PS.ArBill`, `UseCheckBox=true`). Consultant báo: tick checkbox của bill để allocation thì không ăn. Hành vi standard là tick bill thì hệ thống tự điền Receipt Amount.

Hiện tượng quan sát trên Train:
- Receipt Amount = 0: tick checkbox thì checkbox tự bỏ tick ngay, nhìn như bị disable.
- Nhập Receipt Amount (vd 100) thì chỉ đúng 1 dòng được tick, do `autoAlloc()` phân bổ FIFO. Tick thêm dòng khác lại bị bỏ tick.
- Có lỗi phụ: bỏ tick rồi tick lại 1 dòng thì Paid vượt Invoice Amount (vd 46,500 trên bill 46,000, Balance -500).

## 2. Root cause

`gridManager2.AfterCellUpdateHandler`, nhánh `case "checkboxselecter"` (bản CMSD) lấy số tiền phân bổ = `AllocBalance`, tức phần Receipt Amount còn chưa phân bổ:

```js
payamount = igedit_getById(editName + "_AllocBalance").getValue();
//payamount = getBillBalance(billid) * row.get_cellByColumnKey("exchangerate").get_value();
```

- `AllocBalance = 0` thì `AllowAmt(row, 0)` set `checkboxselecter = false`, nên checkbox tự bỏ tick.
- `AllocBalance` không bị chặn theo balance của bill, nên bill có thể bị phân bổ vượt số tiền (Balance âm).

Bản **TFS/standard** dùng dòng ngược lại: tick = trả đủ balance của bill, rồi `summaryToTotal()` tự nâng Receipt Amount (`billAllBaseAmt > cbAmount*rate`). Như vậy bản CMSD đã bị sửa lệch so với standard, và consultant mô tả đúng hành vi standard.

## 3. Fix (chỉ 1 chỗ, theo TFS)

`PSReceiptAdd.aspx`, `AfterCellUpdateHandler`, `case "checkboxselecter"`:

**Before**
```js
    if (row.get_cellByColumnKey("checkboxselecter").get_value())
        payamount = igedit_getById(editName + "_AllocBalance").getValue();
        //payamount = getBillBalance(billid) * row.get_cellByColumnKey("exchangerate").get_value();
    else
        payamount = 0;
```

**After**
```js
    if (row.get_cellByColumnKey("checkboxselecter").get_value())
        //payamount = igedit_getById(editName + "_AllocBalance").getValue();
        payamount = getBillBalance(billid) * row.get_cellByColumnKey("exchangerate").get_value();
    else
        payamount = 0;
```

Không đổi `.aspx.cs`, DB hay config. Deploy chỉ cần copy `.aspx` và Ctrl+F5 xoá cache.

## 4. Kết quả test (Train, unit 01 / TB/SO000001)

- Tick các dòng không liền nhau (1, 4, 5): mỗi dòng nhận đủ balance (46,000 / 250 / 55,000), các dòng đã tick không bị phân bổ lại. `autoAlloc()` không bị kích hoạt lại khi Receipt Amount thay đổi (đã lo ngại do TFS có guard EXSIMDSB-107, nhưng thực tế CMSD không bị).
- Bỏ tick thì Receipt Amount không giảm, phần đó chuyển thành Balance chưa phân bổ. Đây là logic `summaryToTotal()`, giống TFS.
- Tick full và Save: thành công, Document No `TB/OR000003`.

## 5. Ngoài phạm vi (ghi nhận, chưa xử lý)

1. Bản CMSD còn lệch TFS ở nhiều chỗ khác. Đã quyết định KHÔNG đồng bộ, vì các thay đổi đó có rủi ro:
   - Cụm guard allocation EXSIMDSB-107: `isAutoAlloc`, `isManualPayAmt`, delay `AddListLister` 1s, `autoAlloc` bản mới.
   - `payMethodChange` của TFS so khớp tên PayMethod chữ hoa, khác tên PayMethod của CMSD.
   - `AutoCalcInterest` dùng `<%=UnitID%>`, trong khi `UnitID` là private field trong `.aspx.cs` CMSD, sẽ lỗi compile.
   - Tab File Upload `PS.FileUpload` cần code-behind và config đi kèm.
   - Chặn phím Enter dùng jQuery.
2. **Actual Collected** hiển thị không khớp Receipt Amount (0.00 / 10.00). Giá trị lấy qua callback `RoundingHelper.GetAmount(Currency, PayMethod, Amount)`, không liên quan ticket.
3. TFS `summaryToTotal` set `cbReceiptAmt = cbBaseAmt` không chia rate. Với ngoại tệ có thể hiển thị sai. Không ảnh hưởng CMSD (vì fix không dùng bản này).

## 6. Jira note (English)

**Root Cause:**
On the Receivable Collection screen (`PSAccount/PSReceiptAdd.aspx`), the Invoice Detail checkbox handler was set to allocate the remaining unallocated Receipt Amount (`AllocBalance`) instead of the selected bill's balance. When Receipt Amount is 0, the amount to allocate is 0, so the system immediately unticks the box and it looks like it cannot be clicked. This also allowed a bill to be over-allocated (e.g. Paid 46,500 on a 46,000 invoice, Balance -500). The CMSD version differs from the IFCA standard (TFS), where ticking a bill pays its full balance and auto-populates the Receipt Amount.

**Fix:**
Aligned the checkbox logic with the standard version: ticking a bill now allocates that bill's full balance and the Receipt Amount is updated automatically. Only `PSReceiptAdd.aspx` is changed; no data or setup change.

**Result:** Tested on Train — bills can be ticked in any order, Receipt Amount is populated correctly, no over-allocation, and the receipt was saved successfully (TB/OR000003).

**Status:** Fixed and tested on Train. Pending deployment to Live.
