// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IERC20 {
    function transferFrom(address from, address to, uint256 value) external returns (bool);
}

/// @title InvoiceLedger
/// @notice On-chain record of invoices and their settlement. An issuer raises an invoice against
/// a payer, the payer settles it (fully or in parts) in a token, and anyone can read the open
/// balance for any payer. Every state change emits an event, so the full history is auditable.
contract InvoiceLedger {
    enum Status { Open, PartiallyPaid, Paid, Cancelled, Overdue }

    struct Invoice {
        address issuer;
        address payer;
        uint256 amount;   // in token units
        uint256 paid;     // settled so far
        uint64 dueDate;   // unix timestamp
        bool cancelled;
    }

    IERC20 public immutable token;
    Invoice[] private invoices;
    mapping(address => uint256[]) private invoiceIdsByPayer;

    event InvoiceCreated(uint256 indexed id, address indexed issuer, address indexed payer, uint256 amount, uint64 dueDate);
    event PaymentMade(uint256 indexed id, address indexed payer, uint256 amount, uint256 totalPaid);
    event InvoiceCancelled(uint256 indexed id);

    constructor(address tokenAddress) {
        require(tokenAddress != address(0), "token required");
        token = IERC20(tokenAddress);
    }

    function createInvoice(address payer, uint256 amount, uint64 dueDate) external returns (uint256 id) {
        require(payer != address(0) && payer != msg.sender, "invalid payer");
        require(amount > 0, "amount must be positive");
        require(dueDate > block.timestamp, "due date must be in the future");
        id = invoices.length;
        invoices.push(Invoice(msg.sender, payer, amount, 0, dueDate, false));
        invoiceIdsByPayer[payer].push(id);
        emit InvoiceCreated(id, msg.sender, payer, amount, dueDate);
    }

    /// @notice Payer settles all or part of an invoice. Payer must first approve this contract on the token.
    function pay(uint256 id, uint256 amount) external {
        Invoice storage inv = _get(id);
        require(msg.sender == inv.payer, "only payer");
        require(!inv.cancelled, "cancelled");
        require(amount > 0 && inv.paid + amount <= inv.amount, "invalid amount");
        inv.paid += amount;
        require(token.transferFrom(msg.sender, inv.issuer, amount), "transfer failed");
        emit PaymentMade(id, msg.sender, amount, inv.paid);
    }

    /// @notice Issuer can cancel an invoice only while nothing has been paid against it.
    function cancel(uint256 id) external {
        Invoice storage inv = _get(id);
        require(msg.sender == inv.issuer, "only issuer");
        require(inv.paid == 0 && !inv.cancelled, "cannot cancel");
        inv.cancelled = true;
        emit InvoiceCancelled(id);
    }

    function statusOf(uint256 id) public view returns (Status) {
        Invoice storage inv = _get(id);
        if (inv.cancelled) return Status.Cancelled;
        if (inv.paid == inv.amount) return Status.Paid;
        if (block.timestamp > inv.dueDate) return Status.Overdue;
        if (inv.paid > 0) return Status.PartiallyPaid;
        return Status.Open;
    }

    function getInvoice(uint256 id) external view returns (Invoice memory inv, Status status) {
        inv = _get(id);
        status = statusOf(id);
    }

    function invoiceCount() external view returns (uint256) {
        return invoices.length;
    }

    /// @notice Total still owed by a payer across all non-cancelled invoices.
    function openBalance(address payer) external view returns (uint256 total) {
        uint256[] storage ids = invoiceIdsByPayer[payer];
        for (uint256 i = 0; i < ids.length; i++) {
            Invoice storage inv = invoices[ids[i]];
            if (!inv.cancelled) total += inv.amount - inv.paid;
        }
    }

    /// @notice Amount past its due date and still unpaid, for a payer.
    function overdueBalance(address payer) external view returns (uint256 total) {
        uint256[] storage ids = invoiceIdsByPayer[payer];
        for (uint256 i = 0; i < ids.length; i++) {
            Invoice storage inv = invoices[ids[i]];
            if (!inv.cancelled && block.timestamp > inv.dueDate) total += inv.amount - inv.paid;
        }
    }

    function invoiceIdsOf(address payer) external view returns (uint256[] memory) {
        return invoiceIdsByPayer[payer];
    }

    function _get(uint256 id) private view returns (Invoice storage) {
        require(id < invoices.length, "no such invoice");
        return invoices[id];
    }
}
